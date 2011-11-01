#pragma once

#include <iostream>

#include <DB/IO/WriteBuffer.h>


namespace DB
{

/** Пишет данные в строку.
  */
class WriteBufferFromString : public WriteBuffer
{
private:
	std::string & s;

	void nextImpl()
	{
		size_t old_size = s.size();
		s.resize(old_size * 2);
		internal_buffer = Buffer(reinterpret_cast<Position>(&s[old_size]), reinterpret_cast<Position>(&*s.end()));
		working_buffer = internal_buffer;
	}

public:
	WriteBufferFromString(std::string & s_)
		: WriteBuffer(reinterpret_cast<Position>(&s_[0]), s_.size()), s(s_)
	{
	}
};

}
