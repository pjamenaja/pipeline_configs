import yaml
from devops.cicd.applications.generators.base_generator import BaseGenerator

class JenkinsGenerator(BaseGenerator):

    def get_content(self):
        obj = self.cfg

        proj_obj = obj["project"]
        project = proj_obj["name"]
        desc = proj_obj["description"]

        header = """
jenkins:
  systemMessage: "{description}"
tool:
  git:
    installations:
    - home: "git"
      name: "Default"
  maven:
    installations:
    - name: "Maven 3"
      properties:
      - installSource:
          installers:
            - maven:
                id: "3.5.4"      
jobs:                  
""".format(description=project)

        script_block = '''
  - script: >
      multibranchPipelineJob("{name}") 
      {{
          displayName("{name}")
          branchSources {{
              git {{
                  id('{name}')
                  remote('{url}')
                  credentialsId('{credential}')
                  includes('{branches_include}')
                  excludes('release/*')
              }}
          }}
          triggers {{
              periodic({trigger_period})
          }}
      }}
'''
        repositories = obj["repositories"]
        jenkins_jobs = obj["jenkins_jobs"]
        blocks = ""

        for job in jenkins_jobs:
            repo_name = job["repository"]
            repo = self.lookup_repo(repositories, repo_name)

            blocks = blocks + script_block.format(
                name=job["name"], 
                branches_include=job["branches_include"],
                trigger_period=job["trigger_period"],
                credential=repo["credential"],
                url=repo["url"])

        content = header + blocks
        return content

    def lookup_repo(self, repositories, repo):
        for rp in repositories:
            if rp["name"] == repo:
                return rp

        dummy = {'url': 'ERROR! - URL not found', 'credential': 'ERROR!!'}
        return dummy
