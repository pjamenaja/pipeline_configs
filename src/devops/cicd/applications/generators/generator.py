from devops.cicd.applications.generators.parser import Parser
from devops.cicd.applications.generators.jeninks_generator import JenkinsGenerator

class Generator:
    basepath = '../configs/'
    projects = ['devops_cicd']

    def run(self):
        for proj in self.projects:
            path = self.basepath + proj + '/'
            inname = proj + '.yaml'
            jenkins_outname = 'jenkins_' + inname

            infile = path + inname
            out_jenkins = path + jenkins_outname

            parser = Parser(infile)
            cfg = parser.parse()

            jkgen = JenkinsGenerator(cfg)
            jkgen.save(out_jenkins)