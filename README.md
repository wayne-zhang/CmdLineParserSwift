# CmdLineParserSwift - A command line argument parser that supports Posix format, Swift 4 

# This project has no other dependencies even test case

# Command line argument definination

# Command line argument, which composed of
#     short name, e.g -a
#     long name, e.g --action
#     a flag that indicates if the argument has or has not value,
#     a list of enumeration values, e.g [create|update|delete]
#     value, e.g the value of argument
#     a flag that indicates if the argument is mandatory
# 
# Initialization pattern as the following:
# 
#    short name,long name,has value[,value enumeration][,mandatory]
# 
# for example
# 
#    -a,--action,true,create|update|delete,true
#    -t,--type,true,CLOB|BLOB
#    -v,--verbose,false
#    -i,--input,true,,true
# 
# 
# @author Wayne Zhang