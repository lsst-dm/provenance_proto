
-- note that DATETIME in some tables is unacceptable, this was done for simplicity. -- It needs to be switched to TIMESTAMP.

CREATE TABLE prv_ProcHistory
    -- <descr>This table produces unique procHistoryIds. The id changes each time
    -- something changes in the provenance. It is not linked to any other table.
    -- Because it is recording the time, it can serve as a "snapshot". E.g., based
    -- on the time we can find out which configurations were valid at that time,
    -- what was executed at that time etc. It also serves as a "flag" that
    -- something has changed.</descr>
(
    procHistoryId BIGINT NOT NULL AUTO_INCREMENT,
        -- <descr>Unique id</descr>
        -- <ucd>meta.id;src</ucd>
    theTime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        -- <descr>Time when this procHistory id was created.</descr>
    description TEXT,
        -- <descr>Description what has changed. This is optional.</descr>
    PRIMARY KEY PK_prvProcHistory_procHistoryId (procHistoryId)
) ENGINE=InnoDB;

CREATE TABLE prv_Pipeline
    -- <descr> This table defines all LSST Pipelines. One row per pipeline.</descr>
(
    pipelineId INT NOT NULL AUTO_INCREMENT,
        -- <descr>Unique id</descr>
        -- <ucd>meta.id;src</ucd>
    pipelineName VARCHAR(64),
        -- <descr>Pipeline name.</descr>
        -- <ucd>meta.id;src</ucd>
    PRIMARY KEY PK_prvPipeline_pipelineId (pipelineId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Pipeline
    -- <descr>This table defines all configurations for all pipelines.</descr>
(
    pipelineCnfId INT NOT NULL AUTO_INCREMENT,
        -- <descr>Unique id</descr>
        -- <ucd>meta.id;src</ucd>
    pipelineId INT NOT NULL,
        -- <descr>Id of the pipeline this configuration is for.</descr>
    validityBegin DATETIME NOT NULL,
        -- <descr>Time when this configuration started to be valid.</descr>
    validityEnd DATETIME NOT NULL,
        -- <descr>Time when this configuration stoped being valid.</descr>
    notes VARCHAR(256),
        -- <descr>Notes/description useful to keep with this configuration.</descr>
    PRIMARY KEY PK_cnfPipeline_pcnfId(pipelineCnfId),
    INDEX IDX_cnfPipeline_pipeId(pipelineId),
    CONSTRAINT FK_cnfPipeline_prv_Pipeline
        FOREIGN KEY(pipelineId)
        REFERENCES prv_Pipeline(pipelineId)
) ENGINE=InnoDB;

CREATE TABLE prv_Task
    -- <descr>This table defines all tasks for all pipelines.</descr>
(
    taskId INT NOT NULL AUTO_INCREMENT,
        -- <descr>Unique id</descr>
        -- <ucd>meta.id;src</ucd>
    taskName VARCHAR(64),
        -- <descr></descr>
    PRIMARY KEY PK_task_taskId(taskId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Pipeline_Tasks
    -- <descr>This is a helper table for prv_cnf_Pipeline, it defines what tasks a
    -- given configuration of a pipeline consists of, and what the order is.
    -- If tasks are arranged hierarchically, parentTaskId determines which parent
    -- task given task belongs to. For tasks that do not have a parent task,
    -- parentTaskId is set to NULL.
    -- Positions should be numbered starting with 1, and are relative to its parent
    -- task.</descr>
(
    pipelineCnfId INT NOT NULL,
    taskId INT NOT NULL,
        -- <descr>Id of the corresponding task.</descr>
    parentTaskId INT DEFAULT NULL,
        -- <descr>Id of the parent task, or NULL if there is no parent task.</descr>
    taskPosition INT NOT NULL,
        -- <descr>Position of the task in the pipeline. Starts with 1.</descr>
    INDEX IDX_pipelineCnfId(pipelineCnfId),
    INDEX IDX_taskId(taskId),
    CONSTRAINT FK_cnfPipeTasks_taskId
        FOREIGN KEY(taskId)
        REFERENCES prv_Task(taskId),
    CONSTRAINT FK_cnfPipeTasks_pipeCnfId
        FOREIGN KEY(pipelineCnfId)
        REFERENCES prv_cnf_Pipeline(pipelineCnfId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Task
    -- <descr>This table defines all configurations for all tasks. Note that
    -- occasionally manual patching will be required, leading to more than one
    -- configuration (the default one, and the patch). This is achieved through
    -- taskCnfVersion column.</descr>
(
    taskCnfId INT NOT NULL AUTO_INCREMENT,
        -- <descr>Unique id</descr>
        -- <ucd>meta.id;src</ucd>
    taskId INT,
        -- <descr>Id of the corresponding task.</descr>
    validityBegin DATETIME NOT NULL,
        -- <descr>Time when this configuration started to be valid.</descr>
    validityEnd DATETIME NOT NULL,
        -- <descr>Time when this configuration stoped being valid.</descr>
    taskCnfVersion INT NOT NULL DEFAULT 1,
        -- <descr>Version of the config (in case there is more than one
        -- configuration that is valid for a given validity range.</descr>
    gitSHA VARCHAR(256),
     -- <descr>We need to capture version of the software used by this task.
     -- For now we are assuming it is just one SHA of one commit in git.
     -- In practice this can be more complicated, it can span multiple repos etc.
     -- </descr>
    PRIMARY KEY PK_cnfTask_prvCnfTaskId(taskCnfId),
    INDEX IDX_cnfTask_taskId(taskId),
    INDEX IDX_cnfTask_cnfVer(taskCnfVersion),
    CONSTRAINT FK_cnfTask_taskId
        FOREIGN KEY(taskId)
        REFERENCES prv_Task(taskId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Task_Columns
    -- <descr>This table defines which tables+columns are altered by a given task.
    -- One row per table+column.</descr>
(
    taskCnfId INT,
        -- <descr>If of the corresponding task configuration.</descr>
    tcName TEXT,
        -- <descr>Table and column pair. Format: "<table>.<column>".
        -- "<table>.*" is allowed to indicate all columns in a table.</descr>
    INDEX IDX_cnfTaskColumns_taskCnfId(taskCnfId),
    CONSTRAINT FK_cnfTaskCols_taskCnfId
        FOREIGN KEY(taskCnfId)
        REFERENCES prv_cnf_Task(taskCnfId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Task_Files
    -- <descr>This table defines which files are altered by a given task.
    -- One row per file. This table can be trivially extended should we capture
    -- which sections of files are altered.</descr>
(
    taskCnfId INT,
        -- <descr>If of the corresponding task configuration.</descr>
    fileUrl TEXT,
        -- <descr>url that uniquely locates the file.</descr>
    INDEX IDX_cnfTaskFiles_taskCnfId(taskCnfId),
    CONSTRAINT FK_cnfTaskFiles_taskCnfId
        FOREIGN KEY(taskCnfId)
        REFERENCES prv_cnf_Task(taskCnfId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Task_KVParams
    -- <descr>This table keeps parameter values for tasks. One row per parameter.
    -- For now everything is kept as strings (not efficient).</descr>
(
    taskCnfId INT,
        -- <descr>If of the corresponding task configuration.</descr>
    theKey VARCHAR(255),
        -- <descr>Unique key.</descr>
    theValue VARCHAR(255),
        -- <descr>Value for the given key.</descr>
    INDEX IDX_cnfTaskKVParams_taskCnfId(taskCnfId),
    CONSTRAINT FK_cnfTaskKVParams_tcId
        FOREIGN KEY(taskCnfId)
        REFERENCES prv_cnf_Task(taskCnfId)
) ENGINE=InnoDB;

CREATE TABLE prv_Node
    -- <descr>This table defines nodes. One row per node.</descr>
(
    nodeId INT NOT NULL AUTO_INCREMENT,
        -- <descr>Unique id</descr>
        -- <ucd>meta.id;src</ucd>
    nodeName VARCHAR(64),
        -- <descr>Name of the node.</descr>
    PRIMARY KEY PK_node_nodeId(nodeId)
) ENGINE=InnoDB;

CREATE TABLE prv_cnf_Node
    -- <descr>This table defines all configurations for all nodes.</descr>
(
    nodeId INT,
        -- <descr></descr>
    validityBegin DATETIME NOT NULL,
        -- <descr>Time when this configuration started to be valid.</descr>
    validityEnd DATETIME NOT NULL,
        -- <descr>Time when this configuration stoped being valid.</descr>
    ip VARCHAR(64),
        -- <descr>IP address (just a silly varchar for now)</descr>
    os VARCHAR(64),
        -- <descr>Operating system name and version.</descr>
    cores INT,
        -- <descr>Number of cores.</descr>
    ram INT,
        -- <descr>Size of memory [GB].</descr>
    INDEX IDX_cnfNode_nodeId(nodeId),
    CONSTRAINT FK_cnfNode_nodeId
        FOREIGN KEY(nodeId)
        REFERENCES prv_Node(nodeId)
) ENGINE=InnoDB;

CREATE TABLE prv_DataBlock
    -- <descr>This table defines blocks of data. A block of data is a group of ids
    -- from the same table that are processed together using the same configuration.
    -- <descr>
(
    blockId BIGINT NOT NULL AUTO_INCREMENT,
        -- <descr>Unique id</descr>
        -- <ucd>meta.id;src</ucd>
    tableName VARCHAR(64) NOT NULL,
        -- <descr>Name of the table this data block is part of.</descr>
    PRIMARY KEY PK_dataBlock_blockd(blockId)
) ENGINE=InnoDB;

CREATE TABLE prv_RowIdToDataBlock
    -- <descr>This table defines which rows belong to a given data block.</descr>
(
    theId BIGINT NOT NULL,
        -- <descr>The id of one data element. Note that we are not enforcing strict
        -- foreign key constraint because this will point to different tables.
        -- </descr>
    blockId BIGINT NOT NULL,
        -- <descr>Id of the block a given row id corresponds to.</descr>
    INDEX IDX_rowIdToDataBlock_theId(theId),
    INDEX IDX_rowIdToDataBlock_blockId(blockId),
    CONSTRAINT FK_rowIdTodataBlock_blockId
        FOREIGN KEY(blockId)
        REFERENCES prv_DataBlock(blockId)
) ENGINE=InnoDB;

CREATE TABLE prv_TaskExecution
    -- <descr>This table keeps information about all tasks ever executed. Since the
    -- configuration of the system is not allowed to change while a tasks is
    -- running, we are not keeping a time range here, but instead we just keep
    -- the time of when the task started. It might be a good idea to keep the
    -- time of the middle of task execution: endTime-startTime/2 to reduce changes
    -- of running into an issue with time synchronization between different
    -- machines.
    -- This table is one of the most important parts
    -- of provenance - it links tasks executions with nodes and processed groups.
    -- Occasionally manual patching will be required, which will lead to more than
    -- one valid configuration of a given task. TaskCnfVersion indicates which
    -- version should be used for a given task execution.
    -- </descr>
(
    taskExecId BIGINT NOT NULL AUTO_INCREMENT,
        -- <descr>Unique id</descr>
        -- <ucd>meta.id;src</ucd>
    taskId INT NOT NULL,
        -- <descr>Id of the task that is executed.</descr>
    nodeId INT NOT NULL,
        -- <descr>Id of the node where the task is executed.</descr>
    theTime DATETIME NOT NULL,
        -- <descr>The time when the task execution was started.</descr>
    taskCnfVersion INT NOT NULL DEFAULT 1,
        -- <descr>Version of the task configuration. Typically there is only one,
        -- in some rare cases when manual patching in required, we can end up with
        -- more than one valid config version.</descr>
    PRIMARY KEY PK_taskExec_taskExecId(taskExecId),
    INDEX IDX_taskExec_taskId(taskId),
    INDEX IDX_taskExec_nodeId(nodeId),
    INDEX IDX_taskExec_cnfVer(taskCnfVersion),
    CONSTRAINT FK_taskExec_taskId
        FOREIGN KEY(taskId)
        REFERENCES prv_Task(taskId),
    CONSTRAINT FK_taskExec_nodeId
        FOREIGN KEY(nodeId)
        REFERENCES prv_Node(nodeId),
    CONSTRAINT FK_taskExec_cnfVersion
        FOREIGN KEY(taskCnfVersion)
        REFERENCES prv_cnf_Task(taskCnfVersion)
) ENGINE=InnoDB;

CREATE TABLE prv_TaskExecutionToInputDataBlock
    -- <descr>This table maps tasks executions to input DataBlocks. Each block is
    -- typically processed by multiple task executions, and each task execution
    -- may process multiple data blocks, so it is many-to-many.</descr>
(
    taskExecId BIGINT NOT NULL,
        -- <descr>Id of the task execution.</descr>
    blockId BIGINT,
        -- <descr>Id of the block a given task execution uses an input or NULL.
        -- </descr>
    INDEX IDX_te2IDB_taskExecId(taskExecId),
    INDEX IDX_ta2IDB_blockIdId(blockId),
    CONSTRAINT FK_te2IDB_taskExecId
        FOREIGN KEY(taskExecId)
        REFERENCES prv_TaskExecution(taskExecId),
    CONSTRAINT FK_te2IDB_blockId
        FOREIGN KEY(blockId)
        REFERENCES prv_DataBlock(blockId)
) ENGINE=InnoDB;

CREATE TABLE prv_TaskExecutionToOutputDataBlock
    -- <descr>This table maps tasks executions to output DataBlocks. Note that each
    -- task execution may output multiple data blocks. There is one entry here for
    -- each task execution - output block pair.
(
    taskExecId BIGINT NOT NULL,
        -- <descr>Id of the task execution.</descr>
    blockId BIGINT,
        -- <descr>Id of the block produced by a given task execution or
        -- NULL.</descr>
    INDEX IDX_te2ODB_taskExecId(taskExecId),
    INDEX IDX_ta2ODB_blockId(blockId),
    CONSTRAINT FK_te2ODB_taskExecId
        FOREIGN KEY(taskExecId)
        REFERENCES prv_TaskExecution(taskExecId),
    CONSTRAINT FK_te2ODB_blockId
        FOREIGN KEY(blockId)
        REFERENCES prv_DataBlock(blockId)
) ENGINE=InnoDB;
