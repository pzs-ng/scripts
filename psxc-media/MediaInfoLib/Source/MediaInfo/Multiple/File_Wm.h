// File_Wm - Info for Windows Media files
// Copyright (C) 2002-2007 Jerome Martinez, Zen@MediaArea.net
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 2.1 of the License, or (at your option) any later version.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public
// License along with this library; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
//
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
// Information about Windows Media files
//
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//---------------------------------------------------------------------------
#ifndef MediaInfo_File_WmH
#define MediaInfo_File_WmH
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
#include "MediaInfo/File__Base.h"
//---------------------------------------------------------------------------

namespace MediaInfoLib
{

//***************************************************************************
// Classe File_Wm
//***************************************************************************

class File_Wm : public File__Base
{
protected :
    //Format
    void Read_Buffer_Continue ();

    //Information
    void HowTo (stream_t StreamKind);
};

//***************************************************************************
// Const
//***************************************************************************

namespace Wm
{
    typedef struct _GUID {
      int32u Data1;     //LE
      int16u Data2;     //LE
      int16u Data3;     //LE
      int8u  Data4[2];  //BE
      int8u  Data5[6];  //BE
    } GUID;
    //const char* ASF_Header_Object="75B22630-668E-11CF-A6D9-00AA0062CE6C";
}

} //NameSpace

#endif
