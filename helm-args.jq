# $cmdPosArgs: positional arguments, per command 
. as $cmdArgs # applicable commands per --argument
| $struct | .helm.RELEASE = (.helm.RELEASE // .helm.NAME) | . as $struct
| $struct | .helm.RELEASE_NAME = (.helm.RELEASE_NAME // .helm.NAME) | . as $struct
| $struct.helm | [to_entries[] | select(.key | test("^[A-Z_]+$"))] | from_entries as $positionalArgs
| $struct.helm | [to_entries[] | select(.key | test("^[a-z-]+$"))] | from_entries as $flagArgs
#with_entries( select(any($cmdArgs[.key][]; . == $cmd)))
| $cmdPosArgs[$cmd] // [] 
| map(. as $arg 
    | $positionalArgs[$arg] 
    | if (. == null) then error("missing required argument in struct 'helm' section: " + $arg ) else . end
) as $posArgValues
| $flagArgs | with_entries( select(any($cmdArgs[.key][]; . == $cmd))) as $flagArgValues
#TODO fix ugly hack to guess single argument flags
| [$posArgValues[], ($flagArgValues | to_entries[] | if .value == "true" then "--" + .key else "--" + .key + " " + .value end) ] | join(" ")