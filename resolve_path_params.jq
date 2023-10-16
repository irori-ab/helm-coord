
def resolve_path_params($pathStructureS):
(. / "/") as $pathParts
| ( ($pathStructureS // "" ) / "/")
| to_entries 
| [.[] | select(.value | startswith("#")) | { "key" : .value[1:], "value": $pathParts[.key]} ]
| from_entries;