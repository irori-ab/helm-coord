def join_vars($vars): [.] | flatten
  | map(if . | tostring | startswith("#") 
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
