
-- note that DATETIME in some tables is unacceptable, this was done for simplicity. -- It needs to be switched to TIMESTAMP.

CREATE TABLE prv_ProcHistory (
    -- This table produces unique procHistoryIds. The id changes each time something
    -- changes in the provenance. It is not linked to any other table. Because it
    -- is recording the time, it can serve as a "snapshot". E.g., based on the
    -- time we can find out which configuration were valid at that time, what was
    -- executed at that time etc. It also serves as a "flag" that something has
    -- changed.
    procHistoryId BIGINT NOT NULL AUTO_INCREMENT,
    theTime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                   -- time when this procHistory id was created
    description TEXT,          -- description what has changed
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

CREATE TABLE prv_cnf_Task_Columns (
    -- This table defines which tables+columns are altered by a given task.
    -- One row per table+column.
    taskCnfId INT,
    tcName TEXT, -- table and column pair. Format: "table.column".
                 -- "table.*" is allowed to indicate all columns in a table
    INDEX IDX_cnfTaskColumns_taskCnfId(taskCnfId),
    CONSTRAINT FK_cnfTaskCols_taskCnfId
        FOREIGN KEY(taskCnfId)
        REFERENCES prv_cnf_Task(taskCnfId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Task_Files (
    -- This table defines which files are altered by a given task.
    -- One row per file. This table can be trivially extended should we capture
    -- which sections of files are altered.
    taskCnfId INT,
    fileUrl TEXT, -- url that uniquely locates the file
    INDEX IDX_cnfTaskFiles_taskCnfId(taskCnfId),
    CONSTRAINT FK_cnfTaskFiles_taskCnfId
        FOREIGN KEY(taskCnfId)
        REFERENCES prv_cnf_Task(taskCnfId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Task_KVParams (
    -- This table keeps parameter values for tasks. One row per parameter. For now
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

CREATE TABLE prv_DataBlock (
    -- This table defines blocks of data. A block of data is a group of ids from the
    -- same table that are processed together using the same configuration.
    blockId BIGINT NOT NULL AUTO_INCREMENT,
    tableName VARCHAR(64) NOT NULL,
    PRIMARY KEY PK_dataBlock_blockd(blockId)
) ENGINE=InnoDB;

CREATE TABLE prv_RowIdToDataBlock (
    -- This table defines which rows belong to a given data block.
    theId BIGINT NOT NULL, -- the id of one data element. Note that we are not
                           -- enforcing strict foreign key constraint because this
                           -- will point to different tables.
    blockId BIGINT NOT NULL,
    INDEX IDX_rowIdToDataBlock_theId(theId),
    INDEX IDX_rowIdToDataBlock_blockId(blockId),
    CONSTRAINT FK_rowIdTodataBlock_blockId
        FOREIGN KEY(blockId)
        REFERENCES prv_DataBlock(blockId)
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

CREATE TABLE prv_TaskExecutionToInputDataBlock (
    -- This table maps tasks executions to input DataBlocks. Each block is
    -- typically processed by multiple task executions, and each task execution
    -- may process multiple data blocks, so it is many-to-many.
    taskExecId BIGINT NOT NULL,
    blockId BIGINT,  -- block of input data or NULL
    INDEX IDX_te2IDB_taskExecId(taskExecId),
    INDEX IDX_ta2IDB_blockIdId(blockId),
    CONSTRAINT FK_te2IDB_taskExecId
        FOREIGN KEY(taskExecId)
        REFERENCES prv_TaskExecution(taskExecId),
    CONSTRAINT FK_te2IDB_blockId
        FOREIGN KEY(blockId)
        REFERENCES prv_DataBlock(blockId)
) ENGINE=InnoDB;

CREATE TABLE prv_TaskExecutionToOutputDataBlock (
    -- This table maps tasks executions to output DataBlocks. Note that each task
    -- execution may output multiple data blocks. There is one entry here for each
    -- task execution - output block pair.
    taskExecId BIGINT NOT NULL,
    blockId BIGINT,  -- block of input data or NULL
    INDEX IDX_te2ODB_taskExecId(taskExecId),
    INDEX IDX_ta2ODB_blockId(blockId),
    CONSTRAINT FK_te2ODB_taskExecId
        FOREIGN KEY(taskExecId)
        REFERENCES prv_TaskExecution(taskExecId),
    CONSTRAINT FK_te2ODB_blockId
        FOREIGN KEY(blockId)
        REFERENCES prv_DataBlock(blockId)
) ENGINE=InnoDB;
