// Trimmed from a real Word paste: the <head>/<style> block is what used to
// leak into the note, the body carries real formatting and no table.
export const WORD_HTML = `<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">
<head>
<meta charset="utf-8">
<meta name=ProgId content=Word.Document>
<!--[if gte mso 9]><xml>
 <o:OfficeDocumentSettings>
  <o:AllowPNG/>
 </o:OfficeDocumentSettings>
</xml><![endif]-->
<style>
<!--
 /* Font Definitions */
 @font-face
\t{font-family:"Cambria Math";
\tpanose-1:2 4 5 3 5 4 6 3 2 4;}
 /* Style Definitions */
 p.MsoNormal, li.MsoNormal, div.MsoNormal
\t{margin:0cm;
\tfont-size:10.5pt;
\tfont-family:"游明朝",serif;}
 @page WordSection1
\t{size:595.3pt 841.9pt;
\tmargin:85.05pt 85.05pt 85.05pt 85.05pt;}
 div.WordSection1
\t{page:WordSection1;}
-->
</style>
</head>
<body lang=JA style='tab-interval:21.0pt;word-wrap:break-word'>
<div class=WordSection1>
<p class=MsoNormal><b>Bold text</b> and normal text.<o:p></o:p></p>
</div>
</body>
</html>
`

// Trimmed from a real Excel paste: plain <tr><td> rows, no <thead>/<th>.
export const EXCEL_HTML = `<html xmlns:x="urn:schemas-microsoft-com:office:excel">
<head>
<style>
<!--table
\t{mso-displayed-decimal-separator:"\\.";}
td
\t{color:black;
\tfont-size:11.0pt;
\tfont-family:游ゴシック, sans-serif;}
-->
</style>
</head>
<body>
<table border=0 cellpadding=0 cellspacing=0 width=192>
 <col width=96 span=2>
 <tr height=20>
  <td height=20 class=xl65 width=96>Name</td>
  <td class=xl65 width=96>Score</td>
 </tr>
 <tr height=20>
  <td height=20 class=xl65>Alice</td>
  <td class=xl65>90</td>
 </tr>
</table>
</body>
</html>
`
