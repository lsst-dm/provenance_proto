
import MySQLdb

class CalibPipe(object):
    """
    Calibration Pipeline. It iterates through all raw exposures, takes appropriate
    raw calibration exposure multiplies flux by the v value, and produces science
    calibrated exposure. Depending on the 'algorithm' used in task.
    'Calib A', it will set fluxErr to 0.2 or 1 (all very scientific ;)
    """
    def __init__(self, host, port, user, password, db):
        """
        Connect to the Prototype database using provided credentials.
        Note, the database should exist and schema should be loaded.
        """
        self._conn = MySQLdb.connect(host=host, port=port, user=user,
                                     passwd=password, db=db)
        self._conn.autocommit(False)

    def __del__(self):
        """
        Disconnects from the Prototype Database.
        """
        self._conn.close()

    def run(self):
        """
        Runs the pipeline, as described in the class description.
        """
        cursor = self._conn.cursor()
        try:
            # Find version of task 'Calib A'
            cursor.execute('''
SELECT gitSHA
FROM   prv_Pipeline p,
       prv_cnf_Pipeline cp,
       prv_cnf_Pipeline_Tasks pt,
       prv_Task t,
       prv_cnf_Task ct
WHERE  pipelineName = 'Calibration Pipeline'
   AND p.pipelineId=cp.pipelineId
   AND cp.validityEnd='2050-12-31 23:59:59'
   AND pt.pipelineCnfId=cp.pipelineCnfId AND pt.taskId=t.taskId
   AND t.taskName='Calib A'
   AND t.taskId=pt.taskId
   AND ct.taskId=t.taskId
   AND ct.validityEnd='2050-12-31 23:59:59' ''')
            rows = cursor.fetchone()
            if rows[0] == '33226a':
                fluxErr = 0.2
            else:
                fluxErr = 1
            # create science calibrated exposure
            cursor.execute('SELECT rawExposureId FROM RawExposure')
            rows = cursor.fetchall()
            for row in rows:
                cursor.execute('''
INSERT INTO ScienceCalibratedExposure(rawExposureId, filter, ra, decl,
                                      obsStart, cFlux, cFluxErr)
  SELECT r.rawExposureId, r.filter, r.ra, r.decl, r.obsStart, r.flux*c.v, %f
  FROM   RawExposure r, RawCalibExposure c
  WHERE  r.rawExposureId=%s AND r.filter=c.filter
     AND r.ra=c.ra AND r.decl=c.decl''' % (fluxErr, row[0]))
            self._conn.commit()
        except MySQLdb.Error as e:
            print 'Problems: ', e[1], 'when executing:', cursor._last_executed
            self._conn.rollback()
