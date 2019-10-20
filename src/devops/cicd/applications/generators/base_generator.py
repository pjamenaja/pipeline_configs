import yaml

class BaseGenerator():
    cfg = ''

    def __init__(self, obj):
        self.cfg = obj

    def save(self, fname):
        content = self.get_content()

        f = open(fname, "w+")
        f.write(content)
        f.close()

        print("Wrote to file [{}] successfully".format(fname))

    def get_content(self):
        return ""   