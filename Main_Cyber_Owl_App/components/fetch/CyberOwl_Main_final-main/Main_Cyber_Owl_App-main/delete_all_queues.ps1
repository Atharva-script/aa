# Delete all email queue files
$files = @(
    "d:\final_year\Main_Cyber_Owl_App\components\email_system\email_queue.json",
    "d:\final_year\Main_Cyber_Owl_App\mailformat\email_system\email_queue.json",
    "d:\final_year\Main_Cyber_Owl_App\CyberOwl_setup\components\email_system\email_queue.json",
    "d:\final_year\Main_Cyber_Owl_App\CyberOwl_setup\email_system\email_queue.json",
    "d:\final_year\Main_Cyber_Owl_App\CyberOwl_setup\mailformat\email_system\email_queue.json"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "Deleted: $file"
    } else {
        Write-Host "Not found: $file"
    }
}

Write-Host "`nAll queue files deleted!"
