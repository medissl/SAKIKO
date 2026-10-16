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

Say-File 'P01' 'MSTTS_V110_enUS_MarkM' 'Where did everyone go?' 0
Say-File 'P02' 'MSTTS_V110_enUS_MarkM' 'Four locks. There must be keys somewhere.' 0
Say-File 'P03' 'MSTTS_V110_enUS_MarkM' 'The upper floor''s locked. Maybe the staff room has a key.' 0
Say-File 'P04' 'MSTTS_V110_enUS_MarkM' 'This one''s for the upstairs doors.' 0
Say-File 'P05' 'MSTTS_V110_enUS_MarkM' 'She wasn''t smiling in the original.' 0
Say-File 'P06' 'MSTTS_V110_enUS_MarkM' 'The festival exhibit. Upstairs.' 0
Say-File 'P07' 'MSTTS_V110_enUS_MarkM' 'They painted that smile on her.' 0
Say-File 'P08' 'MSTTS_V110_enUS_MarkM' 'There''s a tape. I need somewhere to play it.' 0
Say-File 'P09' 'MSTTS_V110_enUS_MarkM' 'Month, then day. It''s on the festival program.' 0
Say-File 'P10' 'MSTTS_V110_enUS_MarkM' 'Rehearsal room. That must be the old room upstairs.' 0
Say-File 'P11' 'MSTTS_V110_enUS_MarkM' 'They left her here.' 0
Say-File 'P12' 'MSTTS_V110_enUS_MarkM' 'Back to the entrance.' 0
Say-File 'H01' 'MSTTS_V110_enUS_MarkM' 'I should check the staff room.' 0
Say-File 'H02' 'MSTTS_V110_enUS_MarkM' 'That label should match something in the archive.' 0
Say-File 'H03' 'MSTTS_V110_enUS_MarkM' 'There was a media room upstairs.' 0
Say-File 'H04' 'MSTTS_V110_enUS_MarkM' 'The exit''s downstairs, by the shoe lockers.' 0
Say-File 'audition_Mark_wake' 'MSTTS_V110_enUS_MarkM' 'Where did everyone go?' 0
Say-File 'audition_Mark_exhibit' 'MSTTS_V110_enUS_MarkM' 'The festival exhibit. Upstairs.' 0
Say-File 'audition_Mark_chase' 'MSTTS_V110_enUS_MarkM' 'Don''t look back.' 0
Say-File 'audition_David_wake' 'MSTTS_V110_enUS_DavidM' 'Where did everyone go?' 0
Say-File 'audition_David_exhibit' 'MSTTS_V110_enUS_DavidM' 'The festival exhibit. Upstairs.' 0
Say-File 'audition_David_chase' 'MSTTS_V110_enUS_DavidM' 'Don''t look back.' 0
Say-File 'teacher_0' 'MSTTS_V110_enUS_DavidM' 'All right. Open your textbooks to page forty-two.' -1
Say-File 'teacher_1' 'MSTTS_V110_enUS_DavidM' 'We''re going to read the first passage together.' -1
Say-File 'teacher_2' 'MSTTS_V110_enUS_DavidM' 'Look at the first paragraph. Underline anything that tells you how the writer feels.' -1
Say-File 'teacher_3' 'MSTTS_V110_enUS_DavidM' 'You don''t need to finish yet. Take your time.' -1
Say-File 'teacher_4' 'MSTTS_V110_enUS_DavidM' 'We''ll compare your answers in a moment.' -1
Say-File 'student_a_0' 'MSTTS_V110_enUS_MarkM' 'F-twelve is packed. Leave the equipment case in the AV room.' 0
Say-File 'student_a_1' 'MSTTS_V110_enUS_MarkM' 'The festival date. Month, then day. Same as the program.' 0
Say-File 'student_a_2' 'MSTTS_V110_enUS_MarkM' 'I thought you checked.' 0
