// GUI_About - About interface of MediaInfo
// Copyright (C) 2002-2005 Jerome Martinez, Zen@MediaArea.net
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
//
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
// About interface of MediaInfo
//
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//---------------------------------------------------------------------------
// Compilation condition
#ifndef MEDIAINFOGUI_ABOUT_NO
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop
#include "GUI/VCL/GUI_About.h"
#include "Common/Preferences.h"
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma link "TntComCtrls"
#pragma link "TntStdCtrls"
#pragma resource "*.dfm"
TAboutF *AboutF;
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
const ZenLib::Char* MEDIAINFO_ABOUT=     _T("MediaInfo X.X.X.X\\r\\nCopyright (C) 2002-2005 Jerome Martinez");
const wchar_t*      MEDIAINFO_URL=         L"http://mediainfo.sourceforge.net";
const wchar_t*      MEDIAINFO_NEWVERSION=  L"http://sourceforge.net/project/showfiles.php?group_id=86862&package_id=90341";
const wchar_t*      MEDIAINFO_DONATE=      L"http://mediainfo.sourceforge.net/Help";
const wchar_t*      MEDIAINFO_MAILTO=      L"mailto:zenitram@users.sourceforge.net";
//---------------------------------------------------------------------------

//***************************************************************************
// Class
//***************************************************************************

//---------------------------------------------------------------------------
__fastcall TAboutF::TAboutF(TComponent* Owner)
    : TTntForm(Owner)
{
}

//---------------------------------------------------------------------------
void __fastcall TAboutF::FormShow(TObject *Sender)
{
    //Information
    ZenLib::Ztring C1;
    C1+=MEDIAINFO_ABOUT;
    C1.FindAndReplace(_T("X.X.X.X"), MediaInfo_Version_GUI);
    C1+=_T("\r\n\r\n");
    C1+=Prefs->Translate(_T("MediaInfo_About")).c_str();
    C1.FindAndReplace(_T("\\r\\n"), _T("\r\n"), 0, ZenLib::Ztring_Recursive);
    Memo->Text=C1.c_str();

    //Translation
    Caption=Prefs->Translate(_T("About")).c_str();
    OK->Caption=Prefs->Translate(_T("OK")).c_str();
    WebSite->Caption=Prefs->Translate(_T("Go to WebSite")).c_str();
    NewVersion->Caption=Prefs->Translate(_T("CheckNewVersion")).c_str();
    Donate->Caption=Prefs->Translate(_T("Donate")).c_str();
    WriteMe->Caption=Prefs->Translate(_T("WriteMe")).c_str();
    if (Prefs->Translate(_T("  Author_Name")).size()==0)
        Translator->Visible=false;
    else
    {
        Translator->Caption=(Prefs->Translate(_T("Translator"))+Prefs->Translate(_T(": "))+Prefs->Translate(_T("  Author_Name"))).c_str();
        Translator->Visible=true;
    }
    Translator_Url=Prefs->Translate(_T("  Author_Email"));
    if (Translator_Url.size()==0 || Translator_Url==_T("Zen@mediaarea.net"))
        WriteToTranslator->Visible=false;
    else
    {
        WriteToTranslator->Caption=Prefs->Translate(_T("WriteToTranslator")).c_str();
        WriteToTranslator->Visible=true;
    }
}

//---------------------------------------------------------------------------
void __fastcall TAboutF::NewVersionClick(TObject *Sender)
{
    ShellExecute(NULL, NULL, MEDIAINFO_NEWVERSION, NULL, NULL, SW_SHOWNORMAL);
}

//---------------------------------------------------------------------------
void __fastcall TAboutF::DonateClick(TObject *Sender)
{
    ShellExecute(NULL, NULL, MEDIAINFO_DONATE, NULL, NULL, SW_SHOWNORMAL);
}

//---------------------------------------------------------------------------
void __fastcall TAboutF::WriteMeClick(TObject *Sender)
{
    ShellExecute(NULL, NULL, MEDIAINFO_MAILTO, NULL, NULL, SW_SHOWNORMAL);
}

//---------------------------------------------------------------------------
void __fastcall TAboutF::WriteToTranslatorClick(TObject *Sender)
{
    ZenLib::Ztring Url=ZenLib::Ztring(_T("mailto:"))+Translator_Url;
    ShellExecute(NULL, NULL, Url.c_str(), NULL, NULL, SW_SHOWNORMAL);
}

//---------------------------------------------------------------------------
void __fastcall TAboutF::WebSiteClick(TObject *Sender)
{
    ShellExecute(NULL, NULL, MEDIAINFO_URL, NULL, NULL, SW_SHOWNORMAL);
}


//***************************************************************************
// C++
//***************************************************************************

#endif //MEDIAINFOGUI_ABOUT_NO

