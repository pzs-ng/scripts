/*
 * Copyright (C) 2000-2001  Cedric Tefft <cedric@earthling.net>
 * 
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 * 
 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc., 675
 * Mass Ave, Cambridge, MA 02139, USA.
 * 
**************************************************************************
 * 
 * 
 * This file is based in part on:
 * 
 * MP3Info 0.5 by Ricardo Cerqueira <rmc@rccn.net> MP3Stat 0.9 by Ed Sweetman
 * <safemode@voicenet.com> and Johannes Overmann <overmann@iname.com>
 * 
 */

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>
#include "mp3fetch.h"

int		layer_tab  [4] = {0, 3, 2, 1};

int		frequencies[3][4] = {
	{22050, 24000, 16000, 50000},	/* MPEG 2.0 */
	{44100, 48000, 32000, 50000},	/* MPEG 1.0 */
	{11025, 12000, 8000, 50000}	/* MPEG 2.5 */
};

int		bitrate    [2][3][14] = {
	{			/* MPEG 2.0 */
		{32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256},	/* layer 1 */
		{8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160},	/* layer 2 */
		{8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160}	/* layer 3 */
	},

	{			/* MPEG 1.0 */
		{32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448},	/* layer 1 */
		{32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384},	/* layer 2 */
		{32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320}	/* layer 3 */
	}
};

int		frame_size_index[] = {24000, 72000, 72000};

char           *mode_text[] = {
	"Stereo", "Joint Stereo", "Dual Channel", "Mono"
};

char           *emphasis_text[] = {
	"none", "50/15 microsecs", "reserved", "CCITT J 17"
};

char *genre_s[] = {
	"Blues", "Classic Rock", "Country", "Dance",
	"Disco", "Funk", "Grunge", "Hip-Hop",
	"Jazz", "Metal", "New Age", "Oldies",
	"Other", "Pop", "R&B", "Rap",
	"Reggae", "Rock", "Techno", "Industrial",
	"Alternative", "Ska", "Death Metal", "Pranks",
	"Soundtrack", "Euro-Techno", "Ambient", "Trip-Hop",
	"Vocal", "Jazz+Funk", "Fusion", "Trance",
	"Classical", "Instrumental", "Acid", "House",
	"Game", "Sound Clip", "Gospel", "Noise",
	"Alt. Rock", "Bass", "Soul", "Punk",
	"Space", "Meditative", "Instrumental Pop", "Instrumental Rock",
	"Ethnic", "Gothic", "Darkwave", "Techno-Industrial",
	"Electronic", "Pop-Folk", "Eurodance", "Dream",
	"Southern Rock", "Comedy", "Cult", "Gangsta Rap",
	"Top 40", "Christian Rap", "Pop Funk", "Jungle",
	"Native American", "Cabaret", "New Wave", "Psychedelic",
	"Rave", "Showtunes", "Trailer", "Lo-Fi",
	"Tribal", "Acid Punk", "Acid Jazz", "Polka",
	"Retro", "Musical", "Rock & Roll", "Hard Rock",
	"Folk", "Folk Rock", "National Folk", "Swing",
	"Fast-Fusion", "Bebob", "Latin", "Revival",
	"Celtic", "Bluegrass", "Avantgarde", "Gothic Rock",
	"Progressive Rock", "Psychedelic Rock", "Symphonic Rock", "Slow Rock",
	"Big Band", "Chorus", "Easy Listening", "Acoustic",
	"Humour", "Speech", "Chanson", "Opera",
	"Chamber Music", "Sonata", "Symphony", "Booty Bass",
	"Primus", "Porn Groove", "Satire", "Slow Jam",
	"Club", "Tango", "Samba", "Folklore",
	"Ballad", "Power Ballad", "Rhythmic Soul", "Freestyle",
	"Duet", "Punk Rock", "Drum Solo", "A Cappella",
	"Euro-House", "Dance Hall", "Goa", "Drum & Bass",
	"Club-House", "Hardcore", "Terror", "Indie",
	"BritPop", "Negerpunk", "Polsk Punk", "Beat",
	"Christian Gangsta Rap", "Heavy Metal", "Black Metal", "Crossover",
	"Contemporary Christian", "Christian Rock", "Merengue", "Salsa",
	"Thrash Metal", "Anime", "JPop", "Synthpop",
	"Unknown"
};

char *chanmode_s[] = {"Stereo", "Joint Stereo", "Dual Channel", "Single Channel", "Unknown"};
char *layer_s[] = {"Unknown", "Layer III", "Layer II", "Layer I"};
char *codec_s[] = {"Mpeg 2.5", "Unknown", "Mpeg 2", "Mpeg 1"};

int 
header_layer(mp3header * h)
{
	return layer_tab[h->layer];
}

int 
header_bitrate(mp3header * h)
{
	int tvar = 0;
	return bitrate[h->version & 1][3 - h->layer][(tvar = h->bitrate - 1) >= 0 ? tvar : 0 ];
}

int 
header_frequency(mp3header * h)
{
	return frequencies[h->version][h->freq];
}

int 
frame_length(mp3header * header)
{
	return header->sync == 0xFFE ?
	(frame_size_index[3 - header->layer] * ((header->version & 1) + 1) *
	 header_bitrate(header) / header_frequency(header)) +
	header->padding : 1;
}

char           *
header_emphasis(mp3header * h)
{
	return emphasis_text[h->emphasis];
}

char           *
header_mode(mp3header * h)
{
	return mode_text[h->mode];
}

/*
 * Get next MP3 frame header. Return codes: positive value = Frame Length of
 * this header 0 = No, we did not retrieve a valid frame header
 */
int 
get_header(FILE * file, mp3header * header)
{
	unsigned char	buffer[FRAME_HEADER_SIZE];
	int		fl;

	if (fread(&buffer, FRAME_HEADER_SIZE, 1, file) < 1) {
		header->sync = 0;
		return 0;
	}
	header->sync = (((int)buffer[0] << 4) | ((int)(buffer[1] & 0xE0) >> 4));
	if (buffer[1] & 0x10)
		header->version = (buffer[1] >> 3) & 1;
	else
		header->version = 2;
	header->layer = (buffer[1] >> 1) & 3;
	if ((header->sync != 0xFFE) || (header->layer != 1)) {
		header->sync = 0;
		return 0;
	}
	header->crc = buffer[1] & 1;
	header->bitrate = (buffer[2] >> 4) & 0x0F;
	header->freq = (buffer[2] >> 2) & 0x3;
	header->padding = (buffer[2] >> 1) & 0x1;
	header->extension = (buffer[2]) & 0x1;
	header->mode = (buffer[3] >> 6) & 0x3;
	header->mode_extension = (buffer[3] >> 4) & 0x3;
	header->copyright = (buffer[3] >> 3) & 0x1;
	header->original = (buffer[3] >> 2) & 0x1;
	header->emphasis = (buffer[3]) & 0x3;

	return ((fl = frame_length(header)) >= MIN_FRAME_SIZE ? fl : 0);
}

int 
sameConstant(mp3header * h1, mp3header * h2)
{
	if ((*(uint *) h1) == (*(uint *) h2))
		return 1;

	if ((h1->version == h2->version) &&
	    (h1->layer == h2->layer) &&
	    (h1->crc == h2->crc) &&
	    (h1->freq == h2->freq) &&
	    (h1->mode == h2->mode) &&
	    (h1->copyright == h2->copyright) &&
	    (h1->original == h2->original) &&
	    (h1->emphasis == h2->emphasis))
		return 1;
	else
		return 0;
}

int 
get_first_header(mp3info *mp3, int startpos)
{
	int		k         , l = 0, c;
	mp3header	h    , h2;
	int		valid_start = 0;

	fseek(mp3->file, startpos, SEEK_SET);
	while (1) {
		while ((c = fgetc(mp3->file)) != 255 && (c != EOF));
		if (c == 255) {
			ungetc(c, mp3->file);
			valid_start = ftell(mp3->file);
			if ((l = get_header(mp3->file, &h))) {
				fseek(mp3->file, l - FRAME_HEADER_SIZE, SEEK_CUR);
				for (k = 1; (k < MIN_CONSEC_GOOD_FRAMES) && (mp3->datasize - ftell(mp3->file) >= FRAME_HEADER_SIZE); k++) {
					if (!(l = get_header(mp3->file, &h2)))
						break;
					if (!sameConstant(&h, &h2))
						break;
					fseek(mp3->file, l - FRAME_HEADER_SIZE, SEEK_CUR);
				}
				if (k == MIN_CONSEC_GOOD_FRAMES) {
					fseek(mp3->file, valid_start, SEEK_SET);
					memcpy(&(mp3->header), &h2, sizeof(mp3header));
					mp3->header_isvalid = 1;
					return 1;
				}
			}
		} else {
			return 0;
		}
	}

	return 0;
}

/*
 * get_next_header() - read header at current position or look for the next
 * valid header if there isn't one at the current position
 */
int 
get_next_header(mp3info * mp3)
{
	int		l = 0,	c  , skip_bytes = 0;
	mp3header	h;

	while (1) {
		while ((c = fgetc(mp3->file)) != 255 && (ftell(mp3->file) < mp3->datasize))
			skip_bytes++;
		if (c == 255) {
			ungetc(c, mp3->file);
			if ((l = get_header(mp3->file, &h))) {
				if (skip_bytes)
					mp3->badframes++;
				fseek(mp3->file, l - FRAME_HEADER_SIZE, SEEK_CUR);
				return 15 - h.bitrate;
			} else {
				skip_bytes += FRAME_HEADER_SIZE;
			}
		} else {
			if (skip_bytes)
				mp3->badframes++;
			return 0;
		}
	}
}

/* Remove trailing whitespace from the end of a string */
char           *
unpad(char *string)
{
	char           *pos = string + (int)strlen(string) - 1;
	while (isspace(pos[0]))
		(pos--)[0] = 0;
	return string;
}

int 
get_id3(mp3info * mp3, struct audio *audio)
{
	int		retcode = 0;
	char		fbuf      [4];

	if (mp3->datasize >= 128) {
		if (fseek(mp3->file, -128, SEEK_END)) {
			fprintf(stderr, "ERROR: Couldn't read last 128 bytes of %s!!\n", mp3->filename);
			retcode |= 4;
		} else {
			fread(fbuf, 1, 3, mp3->file);
			fbuf[3] = '\0';
			mp3->id3.genre[0] = 255;

			if (!strcmp((const char *)"TAG", (const char *)fbuf)) {
				mp3->id3_isvalid = 1;
				mp3->datasize -= 128;
				fseek(mp3->file, -125, SEEK_END);
				fread(mp3->id3.title, 1, 30, mp3->file);
				mp3->id3.title[30] = '\0';
				fread(mp3->id3.artist, 1, 30, mp3->file);
				mp3->id3.artist[30] = '\0';
				fread(mp3->id3.album, 1, 30, mp3->file);
				mp3->id3.album[30] = '\0';
				fread(mp3->id3.year, 1, 4, mp3->file);
				mp3->id3.year[4] = '\0';
				fread(mp3->id3.comment, 1, 30, mp3->file);
				mp3->id3.comment[30] = '\0';
				if (mp3->id3.comment[28] == '\0') {
					mp3->id3.track[0] = mp3->id3.comment[29];
				}
				fread(mp3->id3.genre, 1, 1, mp3->file);
				unpad(mp3->id3.title);
				unpad(mp3->id3.artist);
				unpad(mp3->id3.album);
				unpad(mp3->id3.year);
				unpad(mp3->id3.comment);

				memcpy(&(audio->id3_artist), &(mp3->id3.artist), sizeof(mp3->id3.artist));
				memcpy(&(audio->id3_title), &(mp3->id3.title), sizeof(mp3->id3.title));
				memcpy(&(audio->id3_album), &(mp3->id3.album), sizeof(mp3->id3.album));
				memcpy(&(audio->id3_year), &(mp3->id3.year), sizeof(mp3->id3.year));
				memcpy(&(audio->id3_artist), &(mp3->id3.artist), sizeof(mp3->id3.artist));
			}
		}
	}
	return retcode;
}

void
get_mp3_info(char *f, struct audio *audio)
{
	int		fullscan = 1;

	FILE           *fp;
	mp3info		mp3;

	int		frame_type [15] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
	float		seconds = 0, total_rate = 0;
	int		frames = 0, frame_types = 0, frames_so_far = 0;
	int		l         , vbr_median = -1;
	int		_bitrate   , lastrate;
	int		counter = 0;
	mp3header	header;
	struct stat	filestat;
	off_t		sample_pos, data_start = 0;

	if (!(fp = fopen(f, "r"))) {
		return;
	}
	memset(&mp3, 0, sizeof(mp3info));

	mp3.filename = f;
	mp3.file = fp;

	stat(mp3.filename, &filestat);
	mp3.datasize = filestat.st_size;
	get_id3(&mp3, audio);

	if (fullscan == 0) {
		if (get_first_header(&mp3, 0L)) {
			data_start = ftell(mp3.file);
			lastrate = 15 - mp3.header.bitrate;
			while ((counter < NUM_SAMPLES) && lastrate) {
				sample_pos = (counter * (mp3.datasize / NUM_SAMPLES + 1)) + data_start;
				if (get_first_header(&mp3, sample_pos)) {
					_bitrate = 15 - mp3.header.bitrate;
				} else {
					_bitrate = -1;
				}
				if (_bitrate != lastrate) {
					mp3.vbr = 1;
					if (fullscan == 0) {
						counter = NUM_SAMPLES;
						fullscan = 1;
					}
				}
				lastrate = _bitrate;
				counter++;
			}
			if (!(fullscan == 1)) {
				mp3.frames = (mp3.datasize - data_start) / (l = frame_length(&mp3.header));
				mp3.seconds = (int)((float)(frame_length(&mp3.header) * mp3.frames) /
						    (float)(header_bitrate(&mp3.header) * 125) + 0.5);
				mp3.vbr_average = (float)header_bitrate(&mp3.header);
			}
		}
	}
	if (fullscan == 1) {
		if (get_first_header(&mp3, 0L)) {
			data_start = ftell(mp3.file);
			while ((_bitrate = get_next_header(&mp3))) {
				frame_type[15 - _bitrate]++;
				frames++;
			}
			memcpy(&header, &(mp3.header), sizeof(mp3header));
			for (counter = 0; counter < 15; counter++) {
				if (frame_type[counter]) {
					frame_types++;
					header.bitrate = counter;
					frames_so_far += frame_type[counter];
					seconds += (float)(frame_length(&header) * frame_type[counter]) /
						(float)(header_bitrate(&header) * 125);
					total_rate += (float)((header_bitrate(&header)) * frame_type[counter]);
					if ((vbr_median == -1) && (frames_so_far >= frames / 2))
						vbr_median = counter;
				}
			}
			mp3.seconds = (int)(seconds + 0.5);
			mp3.header.bitrate = vbr_median;
			mp3.frames = frames - 1;
			mp3.vbr_average = total_rate / mp3.frames;
			if (frame_types > 1) {
				mp3.vbr = 1;
			}
		}
	}
	fclose(mp3.file);
	if (mp3.vbr || *audio->bitrate == '0')
		sprintf(audio->bitrate, "%.0f", (mp3.vbr_average));
//	audio->is_vbr = mp3.vbr;
//	return mp3.vbr_average;
}

/*
 * int main(void) { FILE *fp; char b[32]; sprintf(b, "VBR %.0f",
 * get_mp3_info("test.mp3")); printf("%s\n",b); return 0; }
 */

// ---------------------------------------------------------------------------

char           *
get_preset(char vbr_header[4])
{
	int		preset;
	static char	returnval[10];
	memset(returnval, 0, 10);

	preset = ((unsigned char)vbr_header[0] & 7) * 256 + (unsigned char)vbr_header[1];

	strcpy(returnval, "NA");
	switch (preset) {
	case 1000:
		strcpy(returnval, "APR");
		break;		/* r3mix         */
	case 1001:
		strcpy(returnval, "APS");
		break;		/* standard      */
	case 1002:
		strcpy(returnval, "APE");
		break;		/* extreme       */
	case 1003:
		strcpy(returnval, "API");
		break;		/* insane        */
	case 1004:
		strcpy(returnval, "FAPS");
		break;		/* fast standard */
	case 1005:
		strcpy(returnval, "FAPE");
		break;		/* fast extreme  */
	case 1006:
		strcpy(returnval, "APM");
		break;		/* medium        */
	case 1007:
		strcpy(returnval, "FAPM");
		break;		/* fast medium   */
	case 320:
		strcpy(returnval, "INSANE");
		break;		/* insane        */
	case 410:
		strcpy(returnval, "V9");
		break;          /* V9   */
	case 420:
		strcpy(returnval, "V8");
		break;          /* V8   */
	case 430:
		strcpy(returnval, "V7");
		break;          /* V7   */
	case 440:
		strcpy(returnval, "V6");
		break;          /* V6   */
	case 450:
		strcpy(returnval, "V5");
		break;          /* V5   */
	case 460:
		strcpy(returnval, "V4");
		break;          /* V4   */
	case 470:
		strcpy(returnval, "V3");
		break;          /* V3   */
	case 480:
		strcpy(returnval, "V2");
		break;          /* V2   */
	case 490:
		strcpy(returnval, "V1");
		break;          /* V1   */
	case 500:
		strcpy(returnval, "V0");
		break;          /* V0   */
	}
	return returnval;
}


/*
 * Updated     : 01.22.2002 Author      : Dark0n3
 * 
 * Description : Reads MPEG header from file and stores info to 'audio'.
 */
int
get_mpeg_audio_info(char *f, struct audio *audio)
{
	int		fd;
	int		t_genre;
	int		n;
	int		tag_ok = 0;
	unsigned char	header[4];
	unsigned char	vbr_header[4];
	unsigned char	xing_header1[4], xing_header2[4], xing_header3[4];
	unsigned char	fraunhofer_header[4];
	unsigned char	id3v2_header[10];
	unsigned char	version;
	unsigned char	layer;
	unsigned char	protected = 1;
	unsigned char	t_bitrate;
	unsigned char	t_samplingrate;
	unsigned char	channelmode;
	short int	bitrate = 0;
	short int	br_v1_l3[] = {0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0};
	short int	br_v1_l2[] = {0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, 0};
	short int	br_v1_l1[] = {0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448, 0};
	short int	br_v2_l1[] = {0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256, 0};
	short int	br_v2_l23[] = {0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0};
	unsigned int	samplingrate = 0;
	unsigned int	sr_v1[] = {44100, 48000, 32000, 0};
	unsigned int	sr_v2[] = {22050, 24000, 16000, 0};
	unsigned int	sr_v25[] = {11025, 12000, 8000, 0};
	int		vbr_offset = 0;
	int		t1;
	unsigned char	vbr_oldnew[1];
	unsigned char	vbr_quality[1];
	unsigned char	vbr_minimum_bitrate[1];
	unsigned char	vbr_misc[1];

	fd = open(f, O_RDONLY);
	if (fd < 0)
	{
		printf("Error: could not open file '%s': %s\n", f, strerror(errno));
		strcpy(audio->id3_year, "0000");
		strcpy(audio->id3_title, "Unknown");
		strcpy(audio->id3_artist, "Unknown");
		strcpy(audio->id3_album, "Unknown");
		audio->id3_genre = genre_s[148];

		return 1;
	}

	n = 2;
	while (read(fd, header + 2 - n, n) == n) {
		if (*header == 255) {
			n = 2;
			if (*(header + 1) >= 224) {
				n = 0;
				break;
			} else {
				n = 2;
			}
		} else {
			if (*(header + 1) == 255) {
				*header = *(header + 1);
				n = 1;
			} else {
				n = 2;
			}
		}
	}

	/*
	 * mp3 header: AAAAAAAA AAABBCCD EEEEFFGH IIJJKLMM A - Frame sync B -
	 * MPEG audio version (version) C - Layer (layer) D - Protected by
	 * CRC (protected) E - Bitrate (t_bitrate) F - Sampling rate
	 * (t_samplingrate) G - Padding H - Private bit I - Channel mode
	 * (channelmode) J - Mode extension, K - Copyright L - Original, M -
	 * Emphasis
	 */
	if (n == 0) {
		*(header + 1) -= 224;

		read(fd, header + 2, 2);

		version = (*(header + 1)) >> 3;
		layer = (*(header + 1) >> 1) & ((1 << 2) - 1);	/* Nasty code, keeps CC
								 * in 'layer'. (layer =
								 * (*(header + 1) -
								 * (version << 3)) >> 1) */
		protected = (*(header + 1)) & 1;
		t_bitrate = (*(header + 2)) >> 4;
		t_samplingrate = (*(header + 2) >> 2) & ((1 << 2) - 1);	/* Nasty code, keeps FF
									 * in 't_samplingrate'.
									 * (t_samplingrate =
									 * *(header + 2) -
									 * (t_bitrate << 4) >>
									 * 2) */

		switch (version) {
		case 0:
			samplingrate = sr_v25[t_samplingrate];
		case 2:
			if (!samplingrate)
				samplingrate = sr_v2[t_samplingrate];
			switch (layer) {
			case 3:
				bitrate = br_v2_l1[t_bitrate];
				break;
			case 1:
			case 2:
				bitrate = br_v2_l23[t_bitrate];
				break;
			}
			break;
		case 3:
			samplingrate = sr_v1[t_samplingrate];
			switch (layer) {
			case 1:
				bitrate = br_v1_l3[t_bitrate];
				break;
			case 2:
				bitrate = br_v1_l2[t_bitrate];
				break;
			case 3:
				bitrate = br_v1_l1[t_bitrate];
				break;
			}
			break;
		}
		channelmode = (*(header + 3)) >> 6;

		sprintf(audio->samplingrate, "%i", samplingrate);
		sprintf(audio->bitrate, "%i", bitrate);
		audio->codec = codec_s[version];
		audio->layer = layer_s[layer];
		audio->channelmode = chanmode_s[channelmode];

		/* LAME VBR TAG */
		lseek(fd, 0, SEEK_SET);
		read(fd, id3v2_header, 10);

		if (memcmp(id3v2_header, "ID3", 3) == 0) {
			/*
			 * The ID3V2 tag is prepended to the mp3file, so we
			 * must adjust the vbr_offset accordingly. ID3V2 uses
			 * synchsafe integers hence this bitmanipulation.
			 * Reference :
			 * http://www.id3.org/id3v2.4.0-structure.txt
			 */
			vbr_offset = (id3v2_header[8] >> 1) * 256 + ((id3v2_header[8] & 1) * 128) + id3v2_header[9] + 10;
		}
		lseek(fd, 13 + vbr_offset, SEEK_SET);
		read(fd, xing_header1, 4);
		lseek(fd, 21 + vbr_offset, SEEK_SET);
		read(fd, xing_header2, 4);
		lseek(fd, 36 + vbr_offset, SEEK_SET);
		read(fd, xing_header3, 4);
		lseek(fd, 36 + vbr_offset, SEEK_SET);
		read(fd, fraunhofer_header, 4);

		if (memcmp(xing_header1, "Xing", 4) == 0 ||
		    memcmp(xing_header2, "Xing", 4) == 0 ||
		    memcmp(xing_header2, "LAME", 4) == 0 ||
		    memcmp(xing_header3, "Xing", 4) == 0 ||
		    memcmp(fraunhofer_header, "VBRI", 4) == 0) {

			lseek(fd, 165 + vbr_offset, SEEK_SET);
			read(fd, vbr_oldnew, 1);
			audio->vbr_oldnew[0] = (*vbr_oldnew & 4) >> 2;     // vbr method (vbr-old, vbr-new)

			lseek(fd, 180 + vbr_offset, SEEK_SET);
			read(fd, vbr_misc, 1);
			audio->vbr_noiseshaping = (*vbr_misc & 3);      // vbr noiseshaping
			if (((*vbr_misc & 28) >> 2) == 0)
				sprintf(audio->vbr_stereo_mode, "Mono");
			else if (((*vbr_misc & 28) >> 2) == 1)
				sprintf(audio->vbr_stereo_mode, "Stereo");
			else if (((*vbr_misc & 28) >> 2) == 2)
				sprintf(audio->vbr_stereo_mode, "Dual");
			else if (((*vbr_misc & 28) >> 2) == 3)
				sprintf(audio->vbr_stereo_mode, "Joint");
			else if (((*vbr_misc & 28) >> 2) == 4)
				sprintf(audio->vbr_stereo_mode, "Force");
			else if (((*vbr_misc & 28) >> 2) == 5)
				sprintf(audio->vbr_stereo_mode, "Auto");
			else if (((*vbr_misc & 28) >> 2) == 6)
				sprintf(audio->vbr_stereo_mode, "Intensity");
			else
				sprintf(audio->vbr_stereo_mode, "Undefined");
//			audio->vbr_stereo_mode = (*vbr_misc & 28) >> 2; // vbr stereo mode
			if (((*vbr_misc & 32) >> 5))
				sprintf(audio->vbr_unwise, "Yes");
			else
				sprintf(audio->vbr_unwise, "No");
//			audio->vbr_unwise = (*vbr_misc & 32) >> 5;      // vbr unwise setting
			if (((*vbr_misc & 192) >> 6) == 0)
				sprintf(audio->vbr_source, "<32.000Hz");
			else if (((*vbr_misc & 192) >> 6) == 1)
				sprintf(audio->vbr_source, "44.100Hz");
			else if (((*vbr_misc & 192) >> 6) == 2)
				sprintf(audio->vbr_source, "48.000Hz");
			else
				sprintf(audio->vbr_source, ">48.000Hz");
//			audio->vbr_source = (*vbr_misc & 192) >> 6;     // vbr source sample frequency

			lseek(fd, 176 + vbr_offset, SEEK_SET);
			read(fd, vbr_minimum_bitrate, 1);               // minimumvbr bitrate, or abr bitrate
			audio->vbr_minimum_bitrate = *vbr_minimum_bitrate;

			lseek(fd, 155 + vbr_offset, SEEK_SET);
			read(fd, vbr_quality, 1);                       // vbr quality setting
			audio->vbr_quality = *vbr_quality;

			lseek(fd, 156 + vbr_offset, SEEK_SET);
			read(fd, audio->vbr_version_string, 9);         // vbr version, short string
			audio->vbr_version_string[9] = 0;
			for (t1 = 9; t1 > 0; t1--) {
				if (audio->vbr_version_string[t1] > 32) {
					break;
				}
				audio->vbr_version_string[t1] = 0;
			}
//printf("vbr-method=%d\nvbr-minimum-bitrate=%d\nvbr-quality=%d\nvbr-version=%s\nvbr_noise=%d\nvbr_stereo=%s\nvbr_unwise=%s\nvbr_source=%s\nvbr-misc=%X", (short)audio->vbr_oldnew, (short)audio->vbr_minimum_bitrate, (short)audio->vbr_quality, audio->vbr_version_string, audio->vbr_noiseshaping, audio->vbr_stereo_mode, audio->vbr_unwise, audio->vbr_source, (short)*vbr_misc);

			audio->is_vbr = 1;
			if (memcmp(audio->vbr_version_string, "LAME", 4) == 0) {
				lseek(fd, 182 + vbr_offset, SEEK_SET);
				read(fd, vbr_header, 2);
				sprintf(audio->vbr_preset, "%s", get_preset((char *)vbr_header));

				if (audio->vbr_version_string[4] == 32)
					audio->vbr_version_string[4] = 0;

				/* strcpy(audio->bitrate, "VBR"); */
			} else {
				strcpy(audio->vbr_version_string, "Not LAME");
				strcpy(audio->vbr_preset, "NA");
			}

		} else {
			audio->is_vbr = 0;
			strcpy(audio->vbr_version_string, "NA");
			strcpy(audio->vbr_preset, "NA");
		}

		if (memcmp(fraunhofer_header, "VBRI", 4) == 0) {
			strcpy(audio->vbr_version_string, "FHG");
		}
		/* ID3 TAG */
		lseek(fd, -128, SEEK_END);
		read(fd, header, 3);
		if (memcmp(header, "TAG", 3) == 0) {	/* id3 tag */
			tag_ok = 1;
			read(fd, audio->id3_title, 30);
			read(fd, audio->id3_artist, 30);
			read(fd, audio->id3_album, 30);

			lseek(fd, -35, SEEK_END);
			read(fd, audio->id3_year, 4);
			if (tolower(audio->id3_year[1]) == 'k') {
				memcpy(header, audio->id3_year, 3);
				sprintf(audio->id3_year, "%c00%c", *header, *(header + 2));
			}
			lseek(fd, -1, SEEK_END);
			read(fd, header, 1);
			t_genre = (int)*header;
			if (t_genre < 0)
				t_genre += 256;
			if (t_genre > 148)
				t_genre = 148;

			audio->id3_genre = genre_s[t_genre];
			audio->id3_year[4] =
				audio->id3_artist[30] =
				audio->id3_title[30] =
				audio->id3_album[30] = 0;
		}
	} else {		/* header is broken, shouldnt crc fail? */
		strcpy(audio->samplingrate, "0");
		strcpy(audio->bitrate, "0");
		audio->codec = codec_s[1];
		audio->layer = layer_s[0];
		audio->channelmode = chanmode_s[4];
	}

	if (tag_ok == 0) {
		strcpy(audio->id3_year, "0000");
		strcpy(audio->id3_title, "Unknown");
		strcpy(audio->id3_artist, "Unknown");
		strcpy(audio->id3_album, "Unknown");
		audio->id3_genre = genre_s[148];
	}
	close(fd);

	get_mp3_info(f, audio);
	return 0;
}

int main(int argv, char **argc) {
	struct audio	info;

	if (argv < 2) {
		printf("Syntax: %s <file-name> [1]\n", argc[0]);
		return 0;
	}
	if (get_mpeg_audio_info(argc[1], &info))
		return 1;
	if ((int)strtol(info.bitrate, (char **)NULL, 10) == 0) {
		printf("Error: Is this file really a mp3?\n");
		return 1;
	}
	if (argv > 2 && (int)strtol(argc[2], (char **)NULL, 10) > 0) {
		printf("year             : %s\n", info.id3_year);
		printf("title            : %s\n", info.id3_title);
		printf("artist           : %s\n", info.id3_artist);
		printf("album            : %s\n", info.id3_album);
		printf("genre            : %s\n", info.id3_genre);
		printf("samplingrate     : %s\n", info.samplingrate);
		printf("bitrate          : %s\n", info.bitrate);
		printf("codec            : %s\n", info.codec);
		printf("layer            : %s\n", info.layer);
		printf("channelmode      : %s\n", info.channelmode);
		printf("vbr/cbr          : %s\n", info.is_vbr ? "VBR" : "CBR");
		if (info.is_vbr) {
			printf("vbr version      : %s\n", info.vbr_version_string);
			printf("vbr preset       : %s\n", info.vbr_preset);
			printf("vbr type         : %s\n", *info.vbr_oldnew ? "VBR-NEW" : "VBR-OLD");
			printf("vbr quality      : %d\n", info.vbr_quality);
			printf("vbr min. bitrate : %d\n", info.vbr_minimum_bitrate);
			printf("vbr noiseshaping : %d\n", info.vbr_noiseshaping);
			printf("vbr stereomode   : %s\n", info.vbr_stereo_mode);
			printf("vbr unwise flag  : %s\n", info.vbr_unwise);
			printf("vbr source       : %s\n", info.vbr_source);
		}
	 } else {
		printf("%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s", info.id3_artist, info.id3_title, info.id3_album, info.id3_year, info.id3_genre, info.bitrate, info.is_vbr ? "VBR" : "CBR", info.channelmode, info.samplingrate, info.codec, info.layer);
		if (info.is_vbr)
			printf("|%s|%s|%s|%d|%d|%d|%s|%s|%s", info.vbr_version_string, info.vbr_preset, *info.vbr_oldnew ? "VBR-NEW" : "VBR-OLD", info.vbr_quality, info.vbr_minimum_bitrate, info.vbr_noiseshaping, info.vbr_stereo_mode, info.vbr_unwise, info.vbr_source);
		printf("\n");
	}
	return 0;
}

