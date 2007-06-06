#pragma link "TntDialogs"
//---------------------------------------------------------------------------
// Compilation condition
#ifndef MEDIAINFOGUI_EXPORT_NO
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop
#include "GUI/VCL/GUI_Export.h"
#include "Common/Preferences.h"
#include <wx/filename.h>
#include <wx/file.h>
#include <ZenLib/ZtringListListF.h>
using namespace MediaInfoLib;
using namespace ZenLib;
//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma link "TntComCtrls"
#pragma link "TntStdCtrls"
#pragma resource "*.dfm"
TExportF *ExportF;
//---------------------------------------------------------------------------
#ifdef _UNICODE
    #define ZEN_UNICODE(A) A.c_bstr()
#else
    #define ZEN_UNICODE(A) wxString(A.c_str(), wxConvLocal).c_str()
#endif //_UNICODE
//---------------------------------------------------------------------------

__fastcall TExportF::TExportF(TComponent* Owner)
    : TForm(Owner)
{
}
//---------------------------------------------------------------------------

void TExportF::Name_Adapt()
{
    wxFileName FileName=wxString(Name->Text.c_bstr());

    if (FileName.GetName().size()==0)
        FileName.SetName(_T("Example"));

         if (Export->ActivePage==Export_CSV)
    {
        FileName.SetExt(_T("csv"));
        SaveDialog1->DefaultExt=_T("csv");
        SaveDialog1->Filter=_T("CSV File|*.csv");
    }
    else if (Export->ActivePage==Export_Sheet)
    {
        FileName.SetExt(_T("csv"));
        SaveDialog1->DefaultExt=_T("csv");
        SaveDialog1->Filter=_T("CSV File|*.csv");
    }
    else if (Export->ActivePage==Export_Text)
    {
        FileName.SetExt(_T("txt"));
        SaveDialog1->DefaultExt=_T("txt");
        SaveDialog1->Filter=_T("Text File|*.txt");
    }
    else if (Export->ActivePage==Export_HTML)
    {
        FileName.SetExt(_T("html"));
        SaveDialog1->DefaultExt=_T("html");
        SaveDialog1->Filter=_T("HTML File|*.html");
    }
    else if (Export->ActivePage==Export_Custom)
    {
        if (Prefs->Details[Custom](Stream_Max+2, 1).size()>0 && Prefs->Details[Custom](Stream_Max+2, 1)[0]==_T('<')) //test if HTML
        {
            FileName.SetExt(_T("html"));
            SaveDialog1->DefaultExt=_T("html");
            SaveDialog1->Filter=_T("HTML files|*.htm *.html");
        }
        else
        {
            FileName.SetExt(_T("txt"));
            SaveDialog1->DefaultExt=_T("txt");
            SaveDialog1->Filter=_T("Text files|*.txt");
        }
    }

    Name->Text=FileName.GetFullPath().c_str();
}
//---------------------------------------------------------------------------

int TExportF::Run(MediaInfoLib::MediaInfoList &MI, ZenLib::Ztring DefaultFolder)
{
    //Aquistion of datas
    if (Name->Text.Length()==0)
        Name->Text=DefaultFolder.c_str();
    Name_Adapt();
    ToExport=&MI;

    //GUI
    GUI_Configure();

    return ShowModal();
}
//---------------------------------------------------------------------------

void __fastcall TExportF::Name_FileSelectClick(TObject *Sender)
{
    SaveDialog1->InitialDir=Name->Text;

    if (!SaveDialog1->Execute())
        return;

    Name->Text=SaveDialog1->FileName;
    Name_Adapt();
}
//---------------------------------------------------------------------------

void TExportF::Export_Run()
{
    //Create text for the file
    wxString Text;
    wxString Append_Separator=_T("\r\n");

         if (Export->ActivePage==Export_CSV)
    {
        //Full information
        bool MediaInfo_Complete;
        if (CSV_Advanced->Checked)
            MediaInfo_Complete=true;
        else
            MediaInfo_Complete=false;

        //General
        ZtringListListF CSV;
        ZtringListList Parameters;
        Parameters.Write(MediaInfo::Option_Static(_T("Info_Parameters_CSV")));
        int Pos_Start=1;
        int Pos_End=Parameters.Find(_T("Video"))-1;
        int CSV_Pos=0;

        for (int I1=0; I1<Pos_End-Pos_Start; I1++)
            if (MediaInfo_Complete || ToExport->Get(0, Stream_General, 0, I1, Info_Options)[InfoOption_ShowInInform]==_T('Y'))
            {
                CSV(0, CSV_Pos)=Ztring(_T("General "))+Parameters(Pos_Start+I1, 0);
                for (int FilePos=0; FilePos<ToExport->Count_Get(); FilePos++)
                    CSV(1+FilePos, CSV_Pos)=ToExport->Get(FilePos, Stream_General, 0, I1);
                CSV_Pos++;
            }

        //Video
        Pos_Start=Pos_End+2;
        Pos_End=Parameters.Find(_T("Audio"))-1;

        for (int I1=0; I1<Pos_End-Pos_Start; I1++)
        {
            for (int Count=0; Count<CSV_Stream_Video->ItemIndex; Count++)
            if (MediaInfo_Complete || ToExport->Get(0, Stream_Video, 0, I1, Info_Options)[InfoOption_ShowInInform]==_T('Y'))
                {
                    CSV(0, CSV_Pos)=Ztring(_T("Video "))+Ztring::ToZtring(Count)+_T(" ")+Parameters(Pos_Start+I1, 0);
                    for (int FilePos=0; FilePos<ToExport->Count_Get(); FilePos++)
                        CSV(1+FilePos, CSV_Pos)=ToExport->Get(FilePos, Stream_Video, 0, I1);
                    CSV_Pos++;
                }
        }

        //Audio
        Pos_Start=Pos_End+2;
        Pos_End=Parameters.Find(_T("Text"))-1;
        for (int Count=0; Count<CSV_Stream_Audio->ItemIndex; Count++)
        {
            for (int I1=0; I1<Pos_End-Pos_Start; I1++)
            if (MediaInfo_Complete || ToExport->Get(0, Stream_Audio, 0, I1, Info_Options)[InfoOption_ShowInInform]==_T('Y'))
                {
                    CSV(0, CSV_Pos)=Ztring(_T("Audio "))+Ztring::ToZtring(Count)+_T(" ")+Parameters(Pos_Start+I1, 0);
                    for (int FilePos=0; FilePos<ToExport->Count_Get(); FilePos++)
                        CSV(1+FilePos, CSV_Pos)=ToExport->Get(FilePos, Stream_Audio, Count, I1);
                    CSV_Pos++;
                }
        }

        //Text
        Pos_Start=Pos_End+2;
        Pos_End=Parameters.Find(_T("Chapters"))-1;
        for (int Count=0; Count<CSV_Stream_Text->ItemIndex; Count++)
        {
            for (int I1=0; I1<Pos_End-Pos_Start; I1++)
                if (MediaInfo_Complete || ToExport->Get(0, Stream_Text, 0, I1, Info_Options)[InfoOption_ShowInInform]==_T('Y'))
                {
                    CSV(0, CSV_Pos)=Ztring(_T("Text "))+Ztring::ToZtring(Count)+_T(" ")+Parameters(Pos_Start+I1, 0);
                    for (int FilePos=0; FilePos<ToExport->Count_Get(); FilePos++)
                        CSV(1+FilePos, CSV_Pos)=ToExport->Get(FilePos, Stream_Text, Count, I1);
                    CSV_Pos++;
                }
        }

        //Chapters
        Pos_Start=Pos_End+2;
        Pos_End=Parameters.size()-1;
        for (int Count=0; Count<CSV_Stream_Chapters->ItemIndex; Count++)
        {
            for (int I1=0; I1<Pos_End-Pos_Start; I1++)
            if (MediaInfo_Complete || ToExport->Get(0, Stream_Chapters, 0, I1, Info_Options)[InfoOption_ShowInInform]==_T('Y'))
                {
                    CSV(0, CSV_Pos)=Ztring(_T("Chapters "))+Ztring::ToZtring(Count)+_T(" ")+Parameters(Pos_Start+I1, 0);
                    for (int FilePos=0; FilePos<ToExport->Count_Get(); FilePos++)
                        CSV(1+FilePos, CSV_Pos)=ToExport->Get(FilePos, Stream_Chapters, Count, I1);
                    CSV_Pos++;
                }
        }

        //Separators
        Ztring Separator_Col=ZEN_UNICODE(CSV_Separator_Col->Text);
        if (Separator_Col==_T("(Tab)"))
            Separator_Col=_T("\t");
        Ztring Separator_Line=ZEN_UNICODE(CSV_Separator_Line->Text);
        if (Separator_Line==_T("(Default)"))
        #ifdef WIN32
            Separator_Line=_T("\r\n");
        #else
            #error
        #endif //WIN32
        Separator_Line.FindAndReplace(_T("\\r"), _T("\r"));
        Separator_Line.FindAndReplace(_T("\\n"), _T("\n"));
        Append_Separator=Separator_Line.c_str();
        Ztring Quote=ZEN_UNICODE(CSV_Quote->Text);
        CSV.Separator_Set(0, Separator_Line);
        CSV.Separator_Set(1, Separator_Col);
        CSV.Quote_Set(Quote);

        if (File_Append->Checked)
            CSV.Delete(0);
        Text=CSV.Read().c_str();
    }
    else if (Export->ActivePage==Export_Sheet)
    {
        ZtringListListF SheetF;
        //Configure
        for (size_t Pos=0; Pos<Prefs->Details[Sheet].size(); Pos++)
        {
            Ztring Z1=_T("Column"); Z1+=Ztring::ToZtring(Pos);
            //Searching kind of stream
            stream_t S;
            ZenLib::Char C=_T('G');
            if (Prefs->Details[Sheet].Find(Z1)==(size_t)-1)
                break;
            C=Prefs->Details[Sheet](Z1, 1)[0];
            switch (C)
            {
              case _T('G'): S=Stream_General; break;
              case _T('V'): S=Stream_Video; break;
              case _T('A'): S=Stream_Audio; break;
              case _T('T'): S=Stream_Text; break;
              case _T('C'): S=Stream_Chapters; break;
              default: S=Stream_General;
            }
            SheetF(0, Pos)=ToExport->Get(0, S, Prefs->Details[Sheet](Z1, 2).To_int32u(), Prefs->Details[Sheet](Z1, 3), Info_Name_Text);
            if (C!=_T('G'))
                SheetF(0, Pos)=Prefs->Details[Sheet](Z1, 1)+Prefs->Details[Sheet](Z1, 2)+_T(" ")+SheetF(0, Pos);
        }
        //Show all available files
        for (int FilePos=0; FilePos<ToExport->Count_Get(); FilePos++)
            for (size_t Pos=0; Pos<Prefs->Details[Sheet].size(); Pos++)
            {
                Ztring Z1=_T("Column"); Z1+=Ztring::ToZtring(Pos);
                //Searching Stream kind
                stream_t S;
                ZenLib::Char C=_T('G');
                if (Prefs->Details[Sheet].Find(Z1)==(size_t)-1)
                    break;
                C=Prefs->Details[Sheet](Z1, 1)[0];
                switch (C)
                {
                  case _T('G'): S=Stream_General; break;
                  case _T('V'): S=Stream_Video; break;
                  case _T('A'): S=Stream_Audio; break;
                  case _T('T'): S=Stream_Text; break;
                  case _T('C'): S=Stream_Chapters; break;
                  default: S=Stream_General;
                }
                //Showing
                SheetF(1+FilePos, Pos)=ToExport->Get(FilePos, S, Prefs->Details[Sheet](Z1, 2).To_int32u(), Prefs->Details[Sheet](Z1, 3));
            }

        //Separators
        Ztring Separator_Col=ZEN_UNICODE(Sheet_Separator_Col->Text);
        if (Separator_Col==_T("(Tab)"))
            Separator_Col=_T("\t");
        Ztring Separator_Line=ZEN_UNICODE(Sheet_Separator_Line->Text);
        if (Separator_Line==_T("(Default)"))
        #ifdef WIN32
            Separator_Line=_T("\r\n");
        #else
            #error
        #endif //WIN32
        if (Separator_Line==_T("\\r\\n"))
            Separator_Line=_T("\r\n");
        if (Separator_Line==_T("\\r"))
            Separator_Line=_T("\r");
        if (Separator_Line==_T("\\n"))
            Separator_Line=_T("\n");
        Ztring Quote=ZEN_UNICODE(Sheet_Quote->Text);
        Append_Separator=Separator_Line.c_str();
        SheetF.Separator_Set(0, Separator_Line);
        SheetF.Separator_Set(1, Separator_Col);
        SheetF.Quote_Set(Quote);

        if (File_Append->Checked)
            SheetF.Delete(0);
        Text=SheetF.Read().c_str();
    }
    else if (Export->ActivePage==Export_Text)
    {
        ToExport->Option_Static(_T("Inform"));
        Text=ToExport->Inform(-1).c_str();
    }
    else if (Export->ActivePage==Export_HTML)
    {
        ToExport->Option_Static(_T("Inform"));
        ToExport->Option_Static(_T("HTML;1"));
        Text=ToExport->Inform().c_str();
        ToExport->Option_Static(_T("HTML;0"));
        Append_Separator=_T("<hr>\r\n");
    }
    else if (Export->ActivePage==Export_Custom)
    {
        ToExport->Option_Static(_T("Inform"), Prefs->Details[Custom].Read());
        if (Custom_One->State==cbChecked)
        {
            wxFileName FileName=wxString(Name->Text.c_bstr());
            for (int FilePos=0; FilePos<ToExport->Count_Get(); FilePos++)
            {
                Ztring Z1=ToExport->Inform(FilePos).c_str();
                //Put begin and end of file
                Z1=Prefs->Details[Custom](Stream_Max+2, 1)+Z1; //Begin
                Z1+=Prefs->Details[Custom](Stream_Max+4, 1); //End
                Z1.FindAndReplace(_T("\\r\\n"),_T( "\r\n"), 0, Ztring_Recursive);
                Text=Z1.c_str();;//Write file
                wxFile F;
                wxFileName FN=FileName;
                FN.SetName(FN.GetName()+ Ztring::ToZtring(FilePos).c_str());
                F.Open(FN.GetFullName(), wxFile::write);
                F.Write(Text);
            }
            return; //No need to save the file, already done
        }
        else
            Text=ToExport->Inform().c_str();
    }

    //Writing file
    wxFile F;
    if (File_Append->Checked)
    {
        F.Open(ZEN_UNICODE(Name->Text), wxFile::write_append);
        F.Write(Append_Separator);
    }
    else
        F.Open(ZEN_UNICODE(Name->Text), wxFile::write);
    F.Write(Text);

}
//---------------------------------------------------------------------------

void __fastcall TExportF::ExportChange(TObject *Sender)
{
    Name_Adapt();
}
//---------------------------------------------------------------------------

void __fastcall TExportF::OKClick(TObject *Sender)
{
    Export_Run();
}
//---------------------------------------------------------------------------

void TExportF::CSV_Stream_Change (TTntComboBox* Box, TTntLabel* Label, stream_t Stream)
{
    //Show warning if needed
    bool Warning=false;
    for (int Pos=0; Pos<ToExport->Count_Get(); Pos++)
        if (ToExport->Count_Get(Pos, Stream)>Box->ItemIndex)
            Warning=true;
    Label->Visible=Warning;
}

//---------------------------------------------------------------------------

void __fastcall TExportF::CSV_Stream_VideoChange(TObject *Sender)
{
    CSV_Stream_Change(CSV_Stream_Video, CSV_Stream_Video_Warning, Stream_Video);
}
//---------------------------------------------------------------------------

void __fastcall TExportF::CSV_Stream_AudioChange(TObject *Sender)
{
    CSV_Stream_Change(CSV_Stream_Audio, CSV_Stream_Audio_Warning, Stream_Audio);
}
//---------------------------------------------------------------------------

void __fastcall TExportF::CSV_Stream_TextChange(TObject *Sender)
{
    CSV_Stream_Change(CSV_Stream_Text, CSV_Stream_Text_Warning, Stream_Text);
}
//---------------------------------------------------------------------------

void __fastcall TExportF::CSV_Stream_ChaptersChange(TObject *Sender)
{
    CSV_Stream_Change(CSV_Stream_Chapters, CSV_Stream_Chapters_Warning, Stream_Chapters);
}
//---------------------------------------------------------------------------


void TExportF::GUI_Configure()
{
    //Translation
    Caption=Prefs->Translate(_T("Export")).c_str();
    Export_Choose->Caption=Prefs->Translate(_T("Choose export format")).c_str();
    CSV_Stream_Video_Caption->Caption=Prefs->Translate(_T("How many video streams?")).c_str();
    CSV_Stream_Video_Warning->Caption=Prefs->Translate(_T("Warning : more streams in the files")).c_str();
    CSV_Stream_Audio_Caption->Caption=Prefs->Translate(_T("How many audio streams?")).c_str();
    CSV_Stream_Audio_Warning->Caption=Prefs->Translate(_T("Warning : more streams in the files")).c_str();
    CSV_Stream_Text_Caption->Caption=Prefs->Translate(_T("How many text streams?")).c_str();
    CSV_Stream_Text_Warning->Caption=Prefs->Translate(_T("Warning : more streams in the files")).c_str();
    CSV_Stream_Chapters_Caption->Caption=Prefs->Translate(_T("How many chapters streams?")).c_str();
    CSV_Stream_Chapters_Warning->Caption=Prefs->Translate(_T("Warning : more streams in the files")).c_str();
    CSV_Separator_Col_Caption->Caption=Prefs->Translate(_T("Separator_Columns")).c_str();
    CSV_Separator_Line_Caption->Caption=Prefs->Translate(_T("Separator_Lines")).c_str();
    CSV_Quote_Caption->Caption=Prefs->Translate(_T("Quote character")).c_str();
    CSV_Advanced->Caption=Prefs->Translate(_T("Advanced mode")).c_str();
    Export_Sheet->Caption=Prefs->Translate(_T("Sheet")).c_str();
    Sheet_Separator_Col_Caption->Caption=Prefs->Translate(_T("Separator_Columns")).c_str();
    Sheet_Separator_Line_Caption->Caption=Prefs->Translate(_T("Separator_Lines")).c_str();
    Sheet_Quote_Caption->Caption=Prefs->Translate(_T("Quote character")).c_str();
    Export_Text->Caption=Prefs->Translate(_T("Text")).c_str();
    Text_Advanced->Caption=Prefs->Translate(_T("Advanced mode")).c_str();
    Export_HTML->Caption=Prefs->Translate(_T("HTML")).c_str();
    HTML_Advanced->Caption=Prefs->Translate(_T("Advanced mode")).c_str();
    Export_Custom->Caption=Prefs->Translate(_T("Custom")).c_str();
    Custom_One->Caption=Prefs->Translate(_T("One output file per input file")).c_str();
    Name_Choose->Caption=Prefs->Translate(_T("Choose filename")).c_str();
    File_Append->Caption=Prefs->Translate(_T("File_Append")).c_str();
    OK->Caption=Prefs->Translate(_T("OK")).c_str();
    Cancel->Caption=Prefs->Translate(_T("Cancel")).c_str();

    //Sheet - Warnings
    CSV_Stream_Change(CSV_Stream_Video, CSV_Stream_Video_Warning, Stream_Video);
    CSV_Stream_Change(CSV_Stream_Audio, CSV_Stream_Audio_Warning, Stream_Audio);
    CSV_Stream_Change(CSV_Stream_Text, CSV_Stream_Text_Warning, Stream_Text);
    CSV_Stream_Change(CSV_Stream_Chapters, CSV_Stream_Chapters_Warning, Stream_Chapters);
}

//***************************************************************************
// C++
//***************************************************************************

#endif //MEDIAINFOGUI_EXPORT_NO

