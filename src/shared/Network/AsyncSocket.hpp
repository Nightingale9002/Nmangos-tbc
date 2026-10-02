/*
* This file is part of the CMaNGOS Project. See AUTHORS file for Copyright information
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 2 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef MANGOSSERVER_ASYNC_SOCKET
#define MANGOSSERVER_ASYNC_SOCKET

#include "Platform/Define.h"
#include <boost/asio.hpp>
#include <boost/enable_shared_from_this.hpp>
#include "boost/lexical_cast.hpp"
#include "Log/Log.h"
#include "Util/CallerAddress.h"
#include <atomic>

namespace MaNGOS
{
    // this socket is different in that it does not block on reads
    template <typename SocketType>
    class AsyncSocket : public std::enable_shared_from_this<SocketType>
    {
        public:
            AsyncSocket(boost::asio::io_context& io_context);
            virtual ~AsyncSocket();

            void Read(char* buffer, size_t length, std::function<void(const boost::system::error_code&, std::size_t)>&& callback);
            void ReadUntil(std::string& buffer, char delimiter, std::function<void(const boost::system::error_code&, std::size_t)>&& callback);
            void ReadSkip(size_t skipSize, std::function<void(const boost::system::error_code&, std::size_t)>&& callback);
            void Write(const char* buffer, size_t length, std::function<void(const boost::system::error_code&, std::size_t)>&& callback);

            bool Start();
            void Close()
            {
                // [2026-10-03] Every access to the asio socket - initiating an async operation as well as
                // closing/shutting it down - has to go through the same mutex.  boost::asio sockets are
                // "Shared objects: Unsafe": a close() racing with a concurrently initiated async_write can
                // corrupt the reactor's per-descriptor operation list, which ends in the same operation
                // being completed (and its std::function handler destroyed) twice.  That was the 2026-10-03
                // cloud crash: SIGSEGV at 0x11 inside std::_Sp_counted_base::_M_release, reached from the
                // WorldSocket::SendPacket write completion handler (map threads sending while the world
                // thread was tearing the session down / closing the socket).
                //
                // [DIAG 2026-10-03] That same crash reproduced locally on 10-03 00:40 *with* the mutex in
                // place, so we now also record whether a close/destroy happens while writes are still in
                // flight, and who called us (caller address, resolve with Util/CallerAddress.h).
                uintptr_t const caller = MANGOS_CALLER_ADDR();
                std::lock_guard<std::mutex> guard(m_socketOpMutex);
                if (IsClosed())
                    return;

                int const pending = m_outstandingWrites.load(std::memory_order_relaxed);
                if (pending > 0 && !m_pendingWritesReported)
                {
                    m_pendingWritesReported = true;
                    sLog.outError("[SOCKDIAG] close-with-writes-in-flight pending=%d caller=0x%llX base=0x%llX",
                                  pending, static_cast<unsigned long long>(caller),
                                  static_cast<unsigned long long>(MANGOS_IMAGE_BASE()));
                }

                boost::system::error_code ec;
                m_socket.shutdown(boost::asio::ip::tcp::socket::shutdown_both, ec);
                m_socket.close();
            }
            boost::asio::ip::tcp::socket& GetAsioSocket() { return m_socket; }
            virtual bool Deletable() const { return IsClosed(); }
            bool IsClosed() const { return !m_socket.is_open(); }

            boost::asio::ip::address GetRemoteIpAddress() const { return m_remoteAddress; }
            uint16 GetRemotePort() const { return m_remotePort; }

            std::string const& GetRemoteEndpoint() const { return m_remoteEndpoint; }
            std::string const& GetRemoteAddress() const { return m_address; }
        private:
            virtual bool ProcessIncomingData() = 0;
            virtual bool OnOpen() = 0;

            boost::asio::ip::tcp::socket m_socket;

            /// Serializes every asio call made on m_socket (see Close()): operation initiation as well as
            /// shutdown/close.  Without it, map/world threads and the network thread race inside asio.
            std::mutex m_socketOpMutex;

            /// [DIAG 2026-10-03] async_write operations initiated but not yet completed, plus a
            /// one-shot flag so Close()/the destructor can report "closed while writing".
            std::atomic<int> m_outstandingWrites{0};
            bool m_pendingWritesReported = false;
            std::string m_address;
            std::string m_remoteEndpoint;
            boost::asio::ip::address m_remoteAddress;
            uint16 m_remotePort;
    };

    template <typename SocketType>
    MaNGOS::AsyncSocket<SocketType>::AsyncSocket(boost::asio::io_context& io_context) : m_socket(io_context), m_address("0.0.0.0"),
        m_remoteAddress(boost::asio::ip::address()), m_remotePort(0)
    {

    }

    template <typename SocketType>
    MaNGOS::AsyncSocket<SocketType>::~AsyncSocket()
    {
        // [DIAG 2026-10-03] A socket destroyed while a write is still outstanding means the operation
        // (and its handler) outlives the socket impl - the exact shape of the 10-03 local/cloud crashes.
        int const pending = m_outstandingWrites.load(std::memory_order_relaxed);
        if (pending > 0)
            sLog.outError("[SOCKDIAG] destroy-with-writes-in-flight pending=%d base=0x%llX",
                          pending, static_cast<unsigned long long>(MANGOS_IMAGE_BASE()));

        // no other reference to this object can exist here (handlers hold a shared_ptr), so Close() is
        // only used to get the same locked shutdown/close pairing
        Close();
    }

    template <typename SocketType>
    void MaNGOS::AsyncSocket<SocketType>::Read(char* buffer, size_t length, std::function<void(const boost::system::error_code&, std::size_t)>&& callback)
    {
        std::lock_guard<std::mutex> guard(m_socketOpMutex);
        boost::asio::async_read(m_socket, boost::asio::buffer(buffer, length), callback);
    }

    template <typename SocketType>
    void MaNGOS::AsyncSocket<SocketType>::ReadUntil(std::string& buffer, char delimiter, std::function<void(const boost::system::error_code&, std::size_t)>&& callback)
    {
        std::lock_guard<std::mutex> guard(m_socketOpMutex);
        boost::asio::async_read_until(m_socket, boost::asio::dynamic_buffer(buffer, 1024), delimiter, callback);
    }

    template<typename SocketType>
    void AsyncSocket<SocketType>::ReadSkip(size_t skipSize, std::function<void(const boost::system::error_code&, std::size_t)>&& callback)
    {
        std::shared_ptr<std::vector<uint8>> buffer = std::make_shared<std::vector<uint8>>(skipSize);
        Read(reinterpret_cast<char*>(buffer->data()), skipSize, [callback, buffer](const boost::system::error_code& error, std::size_t read)
        {
            callback(error, read);
        });
    }

    template <typename SocketType>
    void MaNGOS::AsyncSocket<SocketType>::Write(const char* buffer, size_t length, std::function<void(const boost::system::error_code&, std::size_t)>&& callback)
    {
        // [DIAG 2026-10-03] count writes that are initiated but not yet completed, and keep the socket
        // alive until the completion runs (the caller's callback - with its buffer ownership - is moved
        // into the wrapper, so the buffer lifetime rules stay exactly as before).
        std::shared_ptr<SocketType> self = this->shared_from_this();
        m_outstandingWrites.fetch_add(1, std::memory_order_relaxed);

        std::lock_guard<std::mutex> guard(m_socketOpMutex);
        boost::asio::async_write(m_socket, boost::asio::buffer(buffer, length),
            [self, cb = std::move(callback)](const boost::system::error_code& ec, std::size_t bytes) mutable
            {
                self->m_outstandingWrites.fetch_sub(1, std::memory_order_relaxed);
                cb(ec, bytes);
            });
    }

    template <typename SocketType>
    bool MaNGOS::AsyncSocket<SocketType>::AsyncSocket::Start()
    {
        try
        {
            m_address = m_socket.remote_endpoint().address().to_string();
            m_remoteEndpoint = boost::lexical_cast<std::string>(m_socket.remote_endpoint());
            m_remoteAddress = m_socket.remote_endpoint().address();
            m_remotePort = m_socket.remote_endpoint().port();
        }
        catch (boost::system::system_error& error)
        {
            sLog.outError("Socket::Open() failed to get remote address.  Error: %s", error.what());
            return false;
        }
        OnOpen();
        ProcessIncomingData();
        return true;
    }

}

#endif
