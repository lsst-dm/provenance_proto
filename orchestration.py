
import MySQLdb

from drpPipe import DRPPipe
from task import Task

class Orchestration(object):
    """
    Mock implementation of pipeline orchestration. It only orchestrates DRP pipe.
    It does it by iterating through all available Science Calibrated Exposures.
    Exposures are processed in groups of 10, except when a configuration change is
    detected (in which case a new group is started right away). It pretends that it
    assigns tasks to nodes. The algorithm is: the first three tasks always run on
    nodes from pool A, and the remaining threee tasks always run on nodes from pool
    B. The nodes used in the pools are taken from provenance.

    After processing the first 70 exposures, it changes one algorithm for one task.
    """
    def __init__(self, host, port, user, password, db):
        """
        Connect to the Prototype database using provided credentials.
        Note, the database should exist and schema should be loaded.

        Get from provenance a list of nodes available for processing, and split
        these nodes into two roughly equal groups, and schedule half of the tasks
        to group A, and the other half to group B.

        Initialize variables used for managing group of exposures
        """
        self._conn = MySQLdb.connect(host=host, port=port, user=user,
                                     passwd=password, db=db)
        self._conn.autocommit(False)
        self._cursor = self._conn.cursor()

        # Find all available nodes to use
        self._cursor.execute('SELECT nodeId FROM prv_Node')
        rows = self._cursor.fetchall()
        nodeIds = list(row[0] for row in rows)

        # Split them into two roughly equal groups
        self._nodeIdsA = nodeIds[:len(nodeIds)/2]
        self._nodeIdsB = nodeIds[len(nodeIds)/2:]

        # Keep track of which one we should be using next in each pool
        self._activeNodeA = 0
        self._activeNodeB = 0

        # Process exposures in groups. Keep the count.
        self._groupId = None
        self._agCount = 0     # count of exposures already processed in that group
        self._maxInGroup = 10 # max count of exposures per group

    def __del__(self):
        """
        Disconnects from the Prototype Database.
        """
        self._conn.close()

    def runDRP(self, pp):
        """
        Do the orchestration as described in the class description.
        """
        drpPipe = DRPPipe()
        try:
            # Fetch all science calibrated exposures to process.
            self._cursor.execute('''
SELECT scExposureId, filter, ra, decl, cFlux
FROM   ScienceCalibratedExposure''')
            rows = self._cursor.fetchall()
            rowN = 0
            for row in rows:
                (scExpId, theFilter, ra, decl, flux) = row
                self._addExposureToGroup(scExpId, pp)
                drpPipe.processExposure(
                    scExpId, theFilter, ra, decl, flux, pp, self._cursor)
                rowN += 1
                if rowN == 70:
                    self._insertNewWCSDeterminationAlgorithm(pp)
            self._conn.commit()
        except MySQLdb.Error as e:
            print 'Problems: ', e[1], 'when executing:', self._cursor._last_executed
            self._conn.rollback()

    def _insertNewWCSDeterminationAlgorithm(self, pp):
        # pretend some time passed and now it is mid October of 2021
        pp.setCurrentTime('2021-10-15 17:42:12')
        # update the algorithms a bit, including changing some input parameters
        pp.updateTaskConfig(self._cursor,
                            Task('WCS Determination',
                                 '4355aa',
                                 {"x":"2.1","y":"5.08","z":"6.7"}))
        # and of course that means we need to update procHistoryId
        pp.createProcHistoryId(self._cursor)

    def _addExposureToGroup(self, scExpId, pp):
        if self._groupId:
            # check if configuration changed, if it did, start a new group
            if self._procHistoryId != pp.getProcHistoryId(self._cursor):
                print "configuration changed, resetting group"
                self._groupId = None

        if self._groupId is None:
            self._cursor.execute('''
INSERT INTO prv_SCEGroup(sceGroupId) VALUES (NULL)''')
            self._groupId = self._cursor.lastrowid
            # determine next available id for the sceGroupId
            # FIXME this has concurrency issue
            #self._cursor.execute('SELECT MAX(sceGroupId) FROM prv_SCEGroup')
            #row = self._cursor.fetchone()
            #if row[0] is None:
            #    self._groupId = 1
            #else:
            #    self._groupId = int(row[0]) + 1
            # register taskExecutions and bind them with the group of exposures
            # that will be processed by these taskExecutions. Let\'s say the first
            # 3 tasks use nodes from pool A, and the other 3 pool B
            for n in ['Image Correction',
                      'WCS Determination',
                      'Photometric Calibration']:
                pp.registerTaskExecution(self._cursor, n,
                    self._nodeIdsA[self._activeNodeA], self._groupId)
            for n in ['Astrometric Calibration',
                      'Image Coaddition',
                      'Classification']:
                pp.registerTaskExecution(self._cursor, n,
                    self._nodeIdsB[self._activeNodeB], self._groupId)
            # and capture the current procHistoryId
            self._procHistoryId = pp.getProcHistoryId(self._cursor)

        # add current exposure to that group
        self._cursor.execute('''
INSERT INTO prv_SCEExposureToGroup(sceGroupId, scExposureId)
VALUES (%s, %s)''' % (self._groupId, scExpId))
        self._agCount += 1
        if self._agCount >= self._maxInGroup:
            self._groupId = None
            self._agCount = 0
            self._activeNodeA += 1
            if self._activeNodeA >=len(self._nodeIdsA):
                self._activeNodeA = 0
            self._activeNodeB += 1
            if self._activeNodeB >=len(self._nodeIdsB):
                self._activeNodeB = 0

        pp.forwardCurrentTime(12)
