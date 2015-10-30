CREATE TABLE Object (
    objectId BIGINT NOT NULL AUTO_INCREMENT,
    ra DOUBLE,
    decl DOUBLE,
    flux DOUBLE,
    PRIMARY KEY PK_objId(objectId)
) ENGINE=MyISAM;

CREATE TABLE Source (
    sourceId BIGINT NOT NULL AUTO_INCREMENT,
    objectId BIGINT NOT NULL,
    scExposureId BIGINT NOT NULL,
    filter CHAR,
    ra DOUBLE,
    decl DOUBLE,
    flux DOUBLE,
    PRIMARY KEY PK_sId(sourceId)
) ENGINE=MyISAM;

CREATE TABLE RawExposure (
    rawExposureId BIGINT NOT NULL AUTO_INCREMENT,
    filter CHAR,
    ra DOUBLE,
    decl DOUBLE,
    obsStart DATETIME,
    flux DOUBLE,
    fluxErr DOUBLE Not NULL DEFAULT 0,
    PRIMARY KEY PK_reId(rawExposureId)
) ENGINE=MyISAM;

CREATE TABLE RawCalibExposure (
    rawCalibExposureId BIGINT NOT NULL AUTO_INCREMENT,
    filter CHAR,
    ra DOUBLE,
    decl DOUBLE,
    v INT,
    PRIMARY KEY PK_reId(rawCalibExposureId)
) ENGINE=MyISAM;

CREATE TABLE ScienceCalibratedExposure (
    scExposureId BIGINT NOT NULL AUTO_INCREMENT,
    rawExposureId BIGINT NOT NULL,
    filter CHAR,
    ra DOUBLE,
    decl DOUBLE,
    obsStart DATETIME,
    cFlux DOUBLE,           -- calibrated flux
    cFluxErr DOUBLE,
    PRIMARY KEY PK_scExId(scExposureId)
) ENGINE=InnoDB;
