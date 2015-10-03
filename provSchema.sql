
CREATE TABLE prv_ProcHistory (
    -- This table produces unique procHistoryIds
    procHistoryId BIGINT NOT NULL AUTO_INCREMENT,
    PRIMARY KEY PK_prvProcHistory_procHistoryId (procHistoryId)
) ENGINE=InnoDB;

CREATE TABLE prv_Pipeline (
    -- This table defines all LSST Pipelines
    pipelineId INT NOT NULL AUTO_INCREMENT,
    pipelineName VARCHAR(64),
    PRIMARY KEY PK_prvPipeline_pipelineId (pipelineId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Pipeline (
    -- This table defines all configurations for all pipelines
    pipelineCnfId INT NOT NULL AUTO_INCREMENT,
    pipelineId INT NOT NULL,
    validityBegin DATETIME NOT NULL,
    validityEnd DATETIME NOT NULL,
    notes VARCHAR(256),
    PRIMARY KEY PK_cnfPipeline_pcnfId(pipelineCnfId),
    INDEX IDX_cnfPipeline_pipeId(pipelineId),
    CONSTRAINT FK_cnfPipeline_prv_Pipeline
        FOREIGN KEY(pipelineId)
        REFERENCES prv_Pipeline(pipelineId)
) ENGINE=InnoDB;

CREATE TABLE prv_Task (
    -- This table defines all tasks for all pipelines
    taskId INT NOT NULL AUTO_INCREMENT,
    taskName VARCHAR(64),
    PRIMARY KEY PK_task_taskId(taskId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Pipeline_Tasks (
    -- This is a helper table for prv_cnf_Pipeline, it defines what tasks a given
    -- configuration of a pipeline consists of, and what the order is. Positions
    -- should be numbered starting with 1.
    pipelineCnfId INT NOT NULL,
    taskId INT NOT NULL,
    taskPosition INT NOT NULL,
    INDEX IDX_pipelineCnfId(pipelineCnfId),
    INDEX IDX_taskId(taskId),
    CONSTRAINT FK_cnfPipeTasks_taskId
        FOREIGN KEY(taskId)
        REFERENCES prv_Task(taskId),
    CONSTRAINT FK_cnfPipeTasks_pipeCnfId
        FOREIGN KEY(pipelineCnfId)
        REFERENCES prv_cnf_Pipeline(pipelineCnfId)
) ENGINE=InnoDB;

CREATE TABLE prv_TableToPipeline (
    -- This table defines which tables are produced by which pipeline
    tableToPipelineId INT NOT NULL AUTO_INCREMENT,
    tableName VARCHAR(64),
    pipelineId INT,
    PRIMARY KEY PK_t2p_id(tableToPipelineId),
    INDEX IDX_t2p_pId(pipelineId),
    CONSTRAINT FK_t2p_pId
        FOREIGN KEY(pipelineId)
        REFERENCES prv_Pipeline(pipelineId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_TableToPipeline (
    tableToPipelineId INT,
    validityBegin DATETIME NOT NULL,
    validityEnd DATETIME NOT NULL,
    INDEX IDX_cnft2p_t2pId(tableToPipelineId),
    CONSTRAINT FK_cnft2p_t2pId
        FOREIGN KEY(tableToPipelineId)
        REFERENCES prv_TableToPipeline(tableToPipelineId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Task (
    taskCnfId INT NOT NULL AUTO_INCREMENT,
    taskId INT,
    validityBegin DATETIME NOT NULL,
    validityEnd DATETIME NOT NULL,
     -- need to capture version of the software used by this task. For this
     -- proof-of-concept prototype I am assuming it is just one SHA of one commit in
     -- git. This can be more complicated, it can span multiple repos etc.
    gitSHA VARCHAR(256),
    PRIMARY KEY PK_cnfTask_prvCnfTaskId(taskCnfId),
    INDEX IDX_cnfTask_taskId(taskId),
    CONSTRAINT FK_cnfTask_taskId
        FOREIGN KEY(taskId)
        REFERENCES prv_Task(taskId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Task_KVParams (
    -- This table keeps parameter values for tasks. One row per param. For now
    -- everything is kept as strings (not efficient)
    taskCnfId INT,
    theKey VARCHAR(255),
    theValue VARCHAR(255),
    INDEX IDX_cnfTaskKVParams_taskCnfId(taskCnfId),
    CONSTRAINT FK_cnfTaskKVParams_tcId
        FOREIGN KEY(taskCnfId)
        REFERENCES prv_cnf_Task(taskCnfId)
) ENGINE=InnoDB;

CREATE TABLE prv_Node (
    nodeId INT NOT NULL AUTO_INCREMENT,
    nodeName VARCHAR(64),
    PRIMARY KEY PK_node_nodeId(nodeId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Node (
    nodeId INT,
    validityBegin DATETIME NOT NULL,
    validityEnd DATETIME NOT NULL,

    -- whatever info we care about keeping per node
    ip VARCHAR(64),       -- IP address (just silly varchar for now)
    os VARCHAR(64),       -- operating system name and version
    cores INT,            -- number of cores
    ram INT,              -- size of memory in GB,
    INDEX IDX_cnfNode_nodeId(nodeId),
    CONSTRAINT FK_cnfNode_nodeId
        FOREIGN KEY(nodeId)
        REFERENCES prv_Node(nodeId)
) ENGINE=InnoDB;

CREATE TABLE prv_SCEGroup (
    -- This table defines groups of ScienceCalibratedExposures that are processed
    -- together using the same configuration.
    sceGroupId BIGINT NOT NULL AUTO_INCREMENT,
    PRIMARY KEY PK_sceGroup_sceGroupId(sceGroupId)
) ENGINE=InnoDB;

CREATE TABLE prv_SCEExposureToGroup (
    -- This table defines which exposures belong to a given group.
    scExposureId BIGINT NOT NULL,
    sceGroupId BIGINT NOT NULL,
    INDEX IDX_sceExpToGroup_expId(scExposureId),
    INDEX IDX_sceExpToGroup_sceGroupId(sceGroupId),
    CONSTRAINT FK_sce_scExposure
        FOREIGN KEY(scExposureId)
        REFERENCES ScienceCalibratedExposure(scExposureId),
    CONSTRAINT FK_sceExpToGroup_sceGroupId
        FOREIGN KEY(sceGroupId)
        REFERENCES prv_SCEGroup(sceGroupId)
) ENGINE=InnoDB;

CREATE TABLE prv_TaskExecution (
    -- This table keeps information about all tasks ever executed. Since the
    -- configuration of the system is not allowed to change while a tasks is
    -- running, we are not keeping a time range here, but instead we just keep
    -- the time of when the task started. This is one of the most important parts
    -- of provenance - it links tasks executions with nodes and processed groups.
    taskExecId BIGINT NOT NULL AUTO_INCREMENT,
    taskId INT NOT NULL,
    nodeId INT NOT NULL,
    theTime DATETIME NOT NULL,
    PRIMARY KEY PK_taskExec_taskExecId(taskExecId),
    INDEX IDX_taskExec_taskId(taskId),
    INDEX IDX_taskExec_nodeId(nodeId),
    CONSTRAINT FK_taskExec_taskId
        FOREIGN KEY(taskId)
        REFERENCES prv_Task(taskId),
    CONSTRAINT FK_taskExec_nodeId
        FOREIGN KEY(nodeId)
        REFERENCES prv_Node(nodeId)
) ENGINE=InnoDB;

CREATE TABLE prv_TaskExecutionToSCEGroup (
    -- This table maps tasks executions to SCEGroups. Each group is typically
    -- processed by multiple task executions, and each task execution may process
    -- multiple groups, so it is many-to-many.
    taskExecId BIGINT NOT NULL,
    sceGroupId BIGINT NOT NULL,
    INDEX IDX_te2sceGroup_taskExecId(taskExecId),
    INDEX IDX_ta2sceGroup_sceGroupId(sceGroupId),
    CONSTRAINT FK_te2sceGroup_taskExecId
        FOREIGN KEY(taskExecId)
        REFERENCES prv_TaskExecution(taskExecId),
    CONSTRAINT FK_te2sceGroup_sceGroupId
        FOREIGN KEY(sceGroupId)
        REFERENCES prv_SCEGroup(sceGroupId)
) ENGINE=InnoDB;
