$ErrorActionPreference='Stop'
$audioRoot=Join-Path $PSScriptRoot '../assets/audio/production'
function Say-File([string]$File,[string]$Token,[string]$Text,[int]$Rate=0) {
  $speech=New-Object -ComObject SAPI.SpVoice
  $voiceToken=New-Object -ComObject SAPI.SpObjectToken
  $voiceToken.SetId('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens\'+$Token)
  $speech.Voice=$voiceToken
  $speech.Rate=$Rate
  $stream=New-Object -ComObject SAPI.SpFileStream
  $stream.Format.Type=22
  $stream.Open((Join-Path $audioRoot ($File+'.wav')),3,$false)
  $speech.AudioOutputStream=$stream
  $null=$speech.Speak($Text)
  $stream.Close()
  Write-Output ('SPEECH '+$File)
}
$mark='MSTTS_V110_enUS_MarkM'
$david='MSTTS_V110_enUS_DavidM'
$zira='MSTTS_V110_enUS_ZiraM'
Say-File teacher_0 $mark 'Please open your textbook to page forty two. Today we will read this passage. First, look at the opening paragraph. Underline anything that catches your attention. I will ask for your impressions afterward.' -1
Say-File teacher_1 $mark 'Read the first paragraph quietly. Take your time. Think about what the writer notices.' -1
Say-File teacher_2 $mark 'Underline the phrase you find most interesting. You do not have to write a long answer.' -1
Say-File teacher_3 $mark 'Now read the next paragraph. Notice how the description changes. Keep working quietly.' -1
Say-File teacher_4 $mark 'We will discuss your impressions next lesson. Finish your sentence, and leave the books on your desks.' -1
Say-File student_a_0 $david 'F twelve is packed. Leave the equipment case in the A V room.' 1
Say-File student_b_0 $zira "What's the combination?" 1
Say-File student_a_1 $david 'The festival date. Month, then day. Same as the program.' 1
Say-File student_b_1 $zira 'Did someone stay behind?' 0
Say-File student_a_2 $david 'I thought you checked.' 0
Say-File chatter_a $david 'Can I borrow your pencil? Thank you. I have almost finished this page.' 0
Say-File chatter_b $zira 'Which paragraph? The first one. I will show you after class.' 1
