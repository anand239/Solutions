$input = Get-Content -Path "C:\Users\achintalapud\Downloads\file11.txt"
$data = $input[1..($input.Length - 1)]

$maxLength = 0

$objects = ForEach($record in $data) {
    $split = $record -split "\s{2,}|\t+"
    If($split.Length -gt $maxLength){
        $maxLength = $split.Length
    }
    $props = @{}
    For($i=0; $i -lt $split.Length; $i++) {
        $props.Add([String]($i+1),$split[$i])
    }
    New-Object -TypeName PSObject -Property $props
}

$headers = [String[]](1..$maxLength)

$objects |
Select-Object $headers | 
Export-Csv -NoTypeInformation -Path "C:\Users\achintalapud\Downloads\file13.csv"