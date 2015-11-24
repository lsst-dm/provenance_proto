#!/usr/bin/env python

from datetime import datetime, timedelta
import random

import MySQLdb

from calibPipe import CalibPipe
from orchestration import Orchestration
from provDetective import ProvDetective
from provProto import ProvProto
from task import Task


class CatalogBuilder(object):
    """
    This class is here to help build a dummy environment that is used for testing
    provenance prototype.
    """
    def __init__(self, host, port, user, password, db):
        self._conn = MySQLdb.connect(host=host, port=port, user=user,
                                     passwd=password, db=db)
        self._cursor = self._conn.cursor()

    def __del__(self):
        self._conn.close()

    def addRawExposure(self, filter, ra, decl, obsStart):
        flux = random.uniform(0.01, 1.5)
        self._cursor.execute('''
INSERT INTO RawExposure(filter, ra, decl, obsStart, flux)
VALUES ("%c", %f, %f, "%s", %f)''' % (filter, ra, decl, obsStart, flux))

    def addRawCalibExposure(self, filter, ra, decl):
        v = random.randint(1, 10)
        self._cursor.execute('''
INSERT INTO RawCalibExposure(filter, ra, decl, v)
VALUES ("%c", %f, %f, "%s")''' % (filter, ra, decl, v))

# ----------------------------------------------------------------------------------

mysqlCredentials = {
    "host": '127.0.0.1',
    "port": 3306,
    "user": 'becla',
    "password": '',
    "db":'provProto'
}

# ----------------------------------------------------------------------------------

def prepareIt():
    # I guess we don't want true random because we want to be able to reproduce,
    # so seed with the same number.
    random.seed(123)

    cr = mysqlCredentials.copy()
    cr['passwd'] = cr['password']
    del cr['password']
    conn = MySQLdb.connect(**cr)
    conn.autocommit(False)
    cursor = conn.cursor()
    pp = ProvProto()

    # pretend we are just starting construction, it is Oct of 2021
    pp.setCurrentTime('2021-10-01 00:00:00')

    # create a new procHistoryId
    pp.createProcHistoryId(cursor)

    # and we are working with two pipelines only for now, They consist of some
    # tasks. We are also keeping track which tables/columns they produce.
    pp.registerPipeline(
        cursor,
        'Calibration Pipeline',
        (Task('Calib A', '33226a'),
         Task('Calib B', '75e3f2', {"firstParam": "invalid"},
              ('RawCalibratedExposure.ra', 'RawCalibratedExposure.decl'))),
        )

    pp.registerPipeline(
        cursor,
        'Data Release Pipeline',
        (Task('Image Correction', 'adf423',
              {"x":"1","y":"2","z":"3.3"}),
         Task('WCS Determination', '3e5567',
              {"x":"2","y":"4","z":"6.6"}, ('Source.ra', 'Source.decl')),
         Task('Photometric Calibration', '55b345',
              {"x":"3","y":"6","z":"9.9"}, ('Source.flux',)),
         Task('Astrometric Calibration', 'f33443',
              {"x":"4","y":"8","z":"12.9"}),
         Task('Image Coaddition', '32116c',
              {"x":"5","y":"10","z":"14.9"}, ('Object.*',)),
         Task('Classification', '8900a2',
              {"x":"6","y":"12","z":"18.4"})))

    # Now the hardware, let's pretend we have 6 nodes for processing
    nodes = [('lsst-dbdev3', '34.56.121.6', 'CentOS 6.7',  8,  16),
             ('lsst-dbdev4', '34.56.121.7', 'CentOS 6.7',  8,  16),
             ('lsst-dev',    '34.56.31.22', 'CentOS 6.7', 32, 128),
             ('lsst7',       '34.56.59.7',  'CentOS 6.7',  8,  32),
             ('lsst8',       '34.56.59.8',  'CentOS 6.7',  8,  32),
             ('lsst9',       '34.56.59.9',  'CentOS 6.7',  8,  32)]

    for node in nodes:
        pp.registerNode(cursor, *node)

    cursor.close()
    conn.commit()

    # Let's say we have 100 different rawExposures. Each exposure have
    # a randomly generated flux. The exposures were taken in one of
    # the 6 filters, in one of the 4 different points of the sky
    cb = CatalogBuilder(**mysqlCredentials)
    t = '2021-10-01 00:00:00'
    for i in range(0, 100):
        f = random.choice(['u','g', 'r', 'i', 'z', 'y'])
        p = random.choice([(10,12), (15,30), (20,29), (75,44)])
        theTime = datetime.strptime(t, "%Y-%m-%d %H:%M:%S")
        theTime += timedelta(seconds=15)
        t = theTime.strftime("%Y-%m-%d %H:%M:%S")
        cb.addRawExposure(f, p[0], p[1], t)

    # And a rawCalibration exposures for each of these parts of the sky
    # for each filter. Each has a randomly generated INT value 1-10
    for f in ('u', 'g', 'r', 'i', 'z', 'y'):
        cb.addRawCalibExposure(f, 10, 12)
        cb.addRawCalibExposure(f, 15, 30)
        cb.addRawCalibExposure(f, 20, 29)
        cb.addRawCalibExposure(f, 75, 44)

    # Now run the calibration pipeline. It is nothing fancy, just one mysql query
    calibPipe = CalibPipe(**mysqlCredentials)
    calibPipe.run()

    # Then we run DRP. This one is more advanced. We run it through orchestration
    # layer, different tasks are run on different nodes etc. This pipeline produces
    # objects and sources.
    orch = Orchestration(pp, **mysqlCredentials)
    orch.runDRP()

# ----------------------------------------------------------------------------------

def queryIt():
    # And finally we do some queries on the provenance
    provDet = ProvDetective(**mysqlCredentials)
    provDet.nodesThatProcessedObject()
    provDet.taskVersionForAllSources('WCS Determination', 10)

# ----------------------------------------------------------------------------------

def main():
    prepareIt()
    queryIt()

# ----------------------------------------------------------------------------------

if __name__ == "__main__":
    main()
