# $structFile: the helm struct file
# $coordFile: the helm coordinate file
# $pathVars: the path structure inferred variables
include "./join_vars";

$structFile
| { 
    "pathVars" : $pathVars, 
    "paramVars" : ( ($structFile.defaultParams // {}) * ($coordFile.params // {}) )
} as $vars
| .helm |= with_entries( { "key": .key , "value": .value | join_vars($vars)})
| .["--values"] |= map(. | join_vars($vars))