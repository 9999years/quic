{-# LANGUAGE PatternSynonyms #-}

-- | This main module provides APIs for QUIC.
module Network.QUIC (
  -- * Running a QUIC client and server
    runQUICClient
  , runQUICServer
  , stopQUICServer
  , Connection
  , isConnectionOpen
  , abortConnection
  , exitConnection
  -- * Stream
  , Stream
  , stream
  , unidirectionalStream
  , streamId
  , StreamId
  , closeStream
  , shutdownStream
  , resetStream
  -- * IO
  , recvStream
  , sendStream
  , sendStreamMany
  -- * Server
  , acceptStream
  -- * Client
  , migrate
  , Migration(..)
  -- * Configrations
  , ClientConfig(..)
  , defaultClientConfig
  , ServerConfig(..)
  , defaultServerConfig
  , Config(..)
  , defaultConfig
  , Hooks(..)
  , defaultHooks
  -- * Types
  , connDebugLog
  , DebugLogger
  , isClientInitiatedBidirectional
  , isServerInitiatedBidirectional
  , isClientInitiatedUnidirectional
  , isServerInitiatedUnidirectional
  , Version(..)
  , fromVersion
  , CID
  , fromCID
  -- ** Parameters
  , Parameters(..)
  , defaultParameters
  -- * Information
  , ConnectionInfo(..)
  , getConnectionInfo
  , ResumptionInfo
  , getResumptionInfo
  , isResumptionPossible
  , is0RTTPossible
  , clientCertificateChain
  -- * Statistics
  , ConnectionStats(..)
  , getConnectionStats
  -- * Exceptions and Errors
  , QUICException(..)
  , TransportError(.., NoError, InternalError, ConnectionRefused, FlowControlError, StreamLimitError, StreamStateError, FinalSizeError, FrameEncodingError, TransportParameterError, ConnectionIdLimitError, ProtocolViolation, InvalidToken, ApplicationError, CryptoBufferExceeded, KeyUpdateError, AeadLimitReached, NoViablePath)
  , cryptoError
  , ApplicationProtocolError(..)
  -- * Synchronization
  , wait0RTTReady
  , wait1RTTReady
  , waitEstablished
  ) where

import Network.QUIC.Client
import Network.QUIC.Config
import Network.QUIC.Connection
import Network.QUIC.IO
import Network.QUIC.Info
import Network.QUIC.Logger
import Network.QUIC.Packet
import Network.QUIC.Parameters
import Network.QUIC.Run
import Network.QUIC.Stream
import Network.QUIC.Types
