import yaml

class Parser:
    filename = ''

    def __init__(self, fname):
        self.filename = fname

    def parse(self):
        stream = open(self.filename, 'r')    
        dictionary = yaml.safe_load(stream)

        return dictionary