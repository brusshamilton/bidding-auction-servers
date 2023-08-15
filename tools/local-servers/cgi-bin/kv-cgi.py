#!/usr/bin/env python3
#
#
import cgi
import json
import sys

form = cgi.FieldStorage()

print("Content-type: application/JSON")
print("X-Allow-FLEDGE: true")
print() # blank line. End of headers

response = {}
if "keys" in form:
  keys = {}
  for key in form.getvalue("keys").split(','):
    keys[key] = {}
  response["keys"] = keys

if "interestGroupNames" in form:
  igs = {}
  for ig in form.getvalue("interestGroupNames").split(','):
    igs[ig] = {'priorityVector': {}}
  response["perInterestGroupData"] = igs

if "renderUrls" in form:
  renderURLs = {}
  for renderURL in form.getvalue("renderUrls").split(','):
    renderURLs[renderURL] = True
  response['renderUrls'] = renderURLs

if "adComponentRenderUrls" in form:
  components = {}
  for com in form.getvalue("adComponentRenderUrls").split(','):
    components[com] = True
  response['adComponentRenderUrls'] = components

print(json.dumps(response), file=sys.stderr)
print(json.dumps(response))
