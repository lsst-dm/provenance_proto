
class Task(object):
    def __init__(self, name, gitSHA, paramKVDict={}, tCols=(), files=()):
        self.name = name
        self.gitSHA = gitSHA
        self.paramKVDict = paramKVDict
        self.tCols = tCols
        self.files = files
