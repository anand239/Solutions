$file ="C:\Users\achintalapud\Downloads\file11.csv"



get-content $file |
    select -Skip 4 |
    set-content "C:\Users\achintalapud\Downloads\file13.csv"