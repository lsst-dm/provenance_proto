
from datetime import datetime, timedelta

import MySQLdb


# ----------------------------------------------------------------------------------

class ProvProto(object):
    '''
    This is a proof-of-concept class that provides API for manipulating provenance.

    It prototype pretends that different events happen at different times,
    so there is interface where we can set current time to anything we want,
    and forward it by some number of seconds.

    Note that the transaction management is expected to be done in the code that
    uses this API. The reason is that we may want to combine multiple updates to
    provenance atomically in various combinations. Strong recommendation: disable
    autocommit: conn.autocommit(False)
    '''
    def __init__(self):
        '''
        Connects to the Prototype database using provided credentials.
        Note, the database should exist and schema should be loaded
        '''
        self._infinity = '2050-12-31 23:59:59'

    def createProcHistoryId(self, cursor):
        '''
        Creates a new procHistoryId.

        @param cursor  Open, valid database cursor
        '''
        cursor.execute('INSERT INTO prv_ProcHistory(procHistoryId) VALUES (NULL)')

    def getProcHistoryId(self, cursor):
        '''
        @param cursor  Open, valid database cursor

        Returns current procHistoryId.
        '''
        cursor.execute('SELECT MAX(procHistoryId) FROM prv_ProcHistory')
        row = cursor.fetchone()
        return row[0]

    def registerPipeline(self, cursor, name, tasks):
        '''
        Registers the pipeline and corresponding configuration in provenance.
        Registers the tasks if they are not registered and attaches them to the
        pipeline configuration.

        @param name    name of the pipeline
        @param tasks   list of task object representing tasks that the pipeline
                       consists of. Order matters
        '''
        # register pipeline in prv_Pipeline
        cursor.execute('''
            INSERT INTO prv_Pipeline(pipelineName) VALUES (%s)''', (name,))
        pipeId = cursor.lastrowid

        # register corresponding config for that pipeline
        notesStr= 'Initial version of %s' % name
        cursor.execute('''
            INSERT INTO prv_cnf_Pipeline(pipelineId, validityBegin, validityEnd,
            notes) VALUES (%s, %s, %s, %s)''',
            (pipeId, self._currentTime, self._infinity, notesStr))
        pipeCnfId = cursor.lastrowid

        # register tasks and their configurations, and attach them to the
        # pipeline
        taskPos = 1
        for task in tasks:
            cursor.execute('''
                SELECT taskId FROM prv_Task WHERE taskName=%s''', (task.name,))
            if cursor.rowcount == 1:
                taskId = cursor.fetchone()[0]
            else:
                cursor.execute('''
                    INSERT INTO prv_Task(taskName) VALUES (%s)''', (task.name,))
                taskId = cursor.lastrowid
            cursor.execute('''
                INSERT INTO prv_cnf_Task(taskId, validityBegin, validityEnd,
                gitSHA) VALUES (%s, %s, %s, %s)''',
                (taskId, self._currentTime, self._infinity, task.gitSHA))
            taskCnfId = cursor.lastrowid
            for k in task.paramKVDict:
                cursor.execute('''
                    INSERT INTO prv_cnf_Task_KVParams(taskCnfId, theKey,
                    theValue) VALUES (%s, %s, %s)''',
                    (taskCnfId, k, task.paramKVDict[k]))
            for c in task.tCols:
                cursor.execute('''
                    INSERT INTO prv_cnf_Task_Columns(taskCnfId, tcName)
                    VALUES (%s, %s)''', (taskCnfId, c))
            cursor.execute('''
                INSERT INTO prv_cnf_Pipeline_Tasks(pipelineCnfId, taskId,
                taskPosition) VALUES (%s, %s, %s)''',
                (pipeCnfId, taskId, taskPos))
            taskPos += 1

    def registerDataBlock(self, cursor, tableName):
        '''
        Registers a new data block entry in provenance.

        @param cursor     Open, valid database cursor
        @param tableName  Table name that corresponds to the block being created.

        Returns the id of the newly registered block.
        '''
        cursor.execute('''
INSERT INTO prv_DataBlock(tableName) VALUES ("%s")''' % tableName)
        return cursor.lastrowid

    def registerRowIdInBlock(self, cursor, blockId, theId):
        '''
        Registers a new rowId in a data block identified by blockId.

        @param cursor  Open, valid database cursor
        @param blockId Data block id
        @param theId   Row id to be associated with a given block
        '''
        cursor.execute('''
INSERT INTO prv_RowIdToDataBlock(blockId, theId)
VALUES (%s, %s)''' % (blockId, theId))

    def registerNode(self, cursor, name, ip, os, cores, ram):
        '''
        Registers processing node in provenance.

        @param cursor  Open, valid database cursor
        @param name    Node name
        @param ip      IP address of the node
        @param os      OS name and version
        @param cores   Number of cores
        @param ram     Memory in GB
        '''
        cursor.execute('INSERT INTO prv_Node(nodeName) VALUES (%s)', (name,))
        nodeId = cursor.lastrowid
        cursor.execute('''
            INSERT INTO prv_cnf_Node(nodeId, validityBegin, validityEnd, ip, os,
            cores, ram) VALUES (%s, %s, %s, %s, %s, %s, %s)''',
            (nodeId, self._currentTime, self._infinity, ip, os, cores, ram))

    def updateTaskConfig(self, cursor, task):
        '''
        Updates the configuration for a given task and updates its validity time:
        sets validity end for the existing configuration object to "now", and
        creates a new configuration with validity "now-->infinity", using values
        passed via task parameter.

        @param cursor     Open, valid database cursor
        @param task       Task object. The names should point to an existing task
                          The values provided will be used as the new values.
        '''
        cursor.execute('''
            SELECT t.taskId FROM prv_cnf_Task ct, prv_Task t
            WHERE  ct.taskId = t.taskId
              AND  t.taskName = %s
              AND  validityEnd=%s''', (task.name, self._infinity))
        taskId = cursor.fetchone()[0]
        cursor.execute('''
            UPDATE prv_cnf_Task SET validityEnd=%s WHERE taskId=%s''',
            (self._currentTime, taskId))
        cursor.execute('''
            INSERT INTO prv_cnf_Task(taskId, validityBegin, validityEnd, gitSHA)
            VALUES (%s, %s, %s, %s)''',
            (taskId, self._currentTime, self._infinity, task.gitSHA))
        taskCnfId = cursor.lastrowid
        for k in task.paramKVDict:
            cursor.execute('''
                INSERT INTO prv_cnf_Task_KVParams(taskCnfId, theKey, theValue)
                VALUES (%s, %s, %s)''', (taskCnfId, k, task.paramKVDict[k]))

    def registerTaskExecution(self, cursor, taskName, nodeId, blockId):
        '''
        Registers a new task execution in provenance.

        @param cursor     Open, valid database cursor
        @param taskName   Name of task to register
        @param nodeId     Id of the node where given task runs.
        @param blockId    Id of data block processed by this taskExecution
        '''
        cursor.execute('SELECT taskId FROM prv_Task WHERE taskName=%s', (taskName,))
        row = cursor.fetchone()
        if row is None:
            print "Can't find task '%s'" % taskName
            raise MySQLdb.Error('Can not find task', taskName)
        taskId = row[0]
        cursor.execute('''
            INSERT INTO prv_TaskExecution(taskId, nodeId, theTime)
            VALUES (%s, %s, %s)''', (taskId, nodeId, self._currentTime))
        taskExecId = cursor.lastrowid
        cursor.execute('''
            INSERT INTO prv_TaskExecutionToInputDataBlock(taskExecId, blockId)
            VALUES (%s, %s)''', (taskExecId, blockId))

    def getNodeIds(self, cursor):
        '''
        Returns a list of all nodeIds registered in provenance.

        @param cursor     Open, valid database cursor
        '''
        cursor.execute('SELECT nodeId FROM prv_Node')
        rows = cursor.fetchall()
        return list(row[0] for row in rows)

    # ------------------------------------------------------------------------------
    # -----       functions below are relately purely to this prototype        -----
    # ------------------------------------------------------------------------------

    def setCurrentTime(self, t):
        '''
        Sets current time to the value passed through t in a form
        'YYYY-MM-DD HH:MM:SS'.
        '''
        self._currentTime = t

    def forwardCurrentTime(self, nSeconds):
        '''
        Adds specified number of seconds to current time.
        '''
        theTime = datetime.strptime(self._currentTime, '%Y-%m-%d %H:%M:%S')
        theTime += timedelta(seconds=nSeconds)
        self._currentTime = theTime.strftime('%Y-%m-%d %H:%M:%S')
