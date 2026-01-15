#!/bin/bash
# Create directory structure
mkdir -p migrations
mkdir -p vault/{config,policies,scripts}
mkdir -p portal/src/{app/{login,dashboard/{accounts,requests}},api/{auth,accounts,requests},components/{ui,layout,accounts,requests},lib,types}

echo "Directory structure created!"
echo "Now copy the file contents from our conversation."
