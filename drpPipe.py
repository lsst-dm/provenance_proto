
import random

import MySQLdb

class DRPPipe(object):
    """
    Data Release Production Pipeline. It iterates through all science
    calibrated exposures and generates objects and sources. The exposures are
    processed on different nodes, in batches of 10. We are switching node for each
    batch, using simple round-robin algorithm. For each exposure it randomly picks
    how many new sources to generate and it creates these sources and corresponding
    new objects; it can generate between 2 and 10 such new sources for each
    exposure. Ra/decl of these sources and objects are randomly generated within
    2x2 box surrounding the center of the image. Then it adds some sources to
    already existing objects, it adds between 10 and 50 such sources. The ra/decl
    is within +/-0.1 of the objects's ra and decl. Source has slightly different
    flux than it's object.

    Select node to process this exposure on. Pretend that we are processing
    different tasks on different pools on nodes. We are switching to a new
    node in round robin fashion, every 10 exposures, so that defines our
    grouping. If configuration changes (if there is a new procHistoryId),
    we are automatically starting a new group.
    """

    def processExposure(self, scExpId, theFilter, ra, decl, flux, pp, cursor):
        """
        @param scExpId    scExposureId
        @param theFilter  filter for that exposure
        @param ra         ra for that exposure
        @param decl       decl for that exposure
        @param flux       flux for that exposure
        @param pp         instance of ProvProto
        @param cursor     open cursor
        """

        # randomly pick how many *new* sources we will generate and create
        # these sources and objects
        nSourcesToGen = random.randint(2, 10)
        for i in range(0, nSourcesToGen):
            # Decide what ra/decl and flux to use, assuming that the area
            # is 2x2.
            objRa = ra + random.uniform(-1, 1)
            objDecl = decl + random.uniform(-1, 1)
            objFlux = random.uniform(0.01, 1)
            # Insert object and source.
            cursor.execute('''
INSERT INTO Object(ra, decl, flux) VALUES (%f, %f, %f)''' % \
                           (objRa, objDecl, objFlux))
            objId = cursor.lastrowid
            cursor.execute('''
INSERT INTO Source(objectId, scExposureId, filter, ra, decl, flux)
VALUES (%s, %s, "%s", %s, %s, %s)''' % \
                     (objId, scExpId, theFilter, objRa, objDecl, objFlux))

        # now add sources to already existing objects
        # fetch all objectIds and ra/decls from the area covered by
        # the current exposure
        cursor.execute('''
SELECT objectId, ra, decl, flux
FROM   Object
WHERE  ra BETWEEN %f AND %f
  AND  decl BETWEEN %f AND %f''' % (ra-1, ra+1, decl-1, decl+1))
        rows = cursor.fetchall()
        # pick some number of sources to add, between 10 and 50
        for i in range(0, random.randint(10, 50)):
            # randomly pick an existing object
            sNo = random.randint(1, len(rows)-1)
            (objId, ra, decl, flux) = rows[sNo]
            # change ra/dec and flux just a little
            sRa = ra + random.uniform(-0.1, 0.1)
            sDecl = decl + random.uniform(-0.1, 0.1)
            sFlux = flux + random.uniform(-0.2, 0.2)
            # and add the source
            cursor.execute('''
INSERT INTO Source(objectId, scExposureId, filter, ra, decl, flux)
VALUES (%s, %s, "%s", %s, %s, %s)''' % \
                       (objId, scExpId, theFilter, sRa, sDecl, sFlux))
