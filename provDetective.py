
import MySQLdb

class ProvDetective(object):
    """
    This class is helping to poke around inside provenance to find things.
    """
    def __init__(self, host, port, user, password, db):
        self._conn = MySQLdb.connect(host=host, port=port, user=user,
                                     passwd=password, db=db)
        self._cursor = self._conn.cursor()

    def __del__(self):
        self._conn.close()

    def _getRandomObjectId(self):
        self._cursor.execute('SELECT objectId FROM Object ORDER BY RAND() LIMIT 1')
        row = self._cursor.fetchone()
        return row[0]

    def _getRandomSourceId(self):
        self._cursor.execute('SELECT sourceId FROM Source ORDER BY RAND() LIMIT 1')
        row = self._cursor.fetchone()
        return row[0]

    def nodesThatProcessedObject(self, objectId=None):
        """
        Prints which node processed a given object. If objectId is none, the
        function will do it for one randomly selected object.
        """
        if objectId is None:
            objectId = self._getRandomObjectId()

        # find all exposures that have sources corresponding to this object
        self._cursor.execute('''
SELECT scExposureId, sourceId, blockId, taskExecId, taskName, nodeName
FROM   Source
JOIN   ScienceCalibratedExposure sce USING(scExposureId)
JOIN   prv_RowIdToDataBlock r ON sce.scExposureId=r.theId
JOIN   prv_TaskExecutionToInputDataBlock USING(blockId)
JOIN   prv_TaskExecution USING(taskExecId)
JOIN   prv_Node USING(nodeId)
JOIN   prv_Task USING(taskId)
WHERE  objectId=%s''' % objectId)
        rows = self._cursor.fetchall()
        print "object with id", objectId, "processsing history, showing:"
        print "scExposureId, sourceId, sceGroupId, taskExecId, taskName, nodeName"
        for row in rows:
            print row

    def taskVersionForAllSources(self, taskName, objectId=None):
        """
        Prints version of the task taskName for all sources of a given object.
        If objectId is none, the function will do it for one randomly selected
        object.
        """
        if objectId is None:
            objectId = self._getRandomObjectId()
        self._cursor.execute('''
SELECT sourceId
FROM   Source
WHERE  objectId='%s' ''' % objectId)
        rows = self._cursor.fetchall()
        for row in rows:
            self.taskVersionForSource(taskName, row[0])


    def taskVersionForSource(self, taskName, sourceId=None):
        """
        Prints version of the task taskName for a given source. If sourceId is
        none, the function will do it for one randomly selected source.
        """
        if sourceId is None:
            sourceId = self._getRandomSourceId()

        # first get the time when given source was processed
        self._cursor.execute('''
SELECT theTime, blockId
FROM   Source
JOIN   ScienceCalibratedExposure sce USING(scExposureId)
JOIN   prv_RowIdToDataBlock r ON sce.scExposureId=r.theId
JOIN   prv_TaskExecutionToInputDataBlock USING(blockId)
JOIN   prv_TaskExecution USING(taskExecId)
WHERE  sourceId=%s''' % sourceId)
        row = self._cursor.fetchone()
        theTime = row[0]
        theGroup = row[1]

        # then find the configuration valid for that time
        self._cursor.execute('''
SELECT gitSHA
FROM   prv_cnf_Task
JOIN   prv_Task USING(taskId)
WHERE  taskName='%s'
  AND  validityBegin <= '%s'
  AND  validityEnd > '%s' ''' % (taskName, theTime, theTime))
        row = self._cursor.fetchone()
        print "Source %s was processed through group %s using '%s' with sha: %s" % \
            (sourceId, theGroup, taskName, row[0])
