def join_vars($vars;$HOME): [.] | flatten
  | map(. 
    | ( tostring | gsub("~"; $HOME))
    | if . | tostring | startswith("#") 
        then 
            $vars.pathVars[.[1:]] 
        else if . | tostring | startswith("$") 
        then 
            $vars.paramVars[.[1:]] 
        else 
            .
        end
    end)
| join("")
;
