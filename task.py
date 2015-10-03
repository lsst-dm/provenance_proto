
class Task(object):
    def __init__(self, name_, gitSHA_, paramKVDict_):
        self.name = name_
        self.gitSHA = gitSHA_
        self.paramKVDict = paramKVDict_
