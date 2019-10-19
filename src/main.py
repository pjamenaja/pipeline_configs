#!/usr/bin/env python

import yaml
import json

try:
    stream = open("../configs/devops_cicd/devops_cicd.yaml", 'r')    
    dictionary = yaml.safe_load(stream)
    json_str = json.dumps(dictionary, indent=3)

    print(json_str)

except yaml.YAMLError as exc:
    print(exc)
