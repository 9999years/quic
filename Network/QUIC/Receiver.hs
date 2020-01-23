{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Network.QUIC.Receiver (
    receiver
  ) where

import Network.TLS.QUIC

import Network.QUIC.Connection
import Network.QUIC.Imports
import Network.QUIC.Packet
import Network.QUIC.Parameters
import Network.QUIC.Types

receiver :: Connection -> IO ()
receiver conn = forever $ do
    cpkts <- connRecv conn
    mapM_ (processCryptPacket conn) cpkts

processCryptPacket :: Connection -> CryptPacket -> IO ()
processCryptPacket conn (CryptPacket header crypt) = do
    let level = packetEncryptionLevel header
    checkEncryptionLevel conn level
    when (isClient conn && level == HandshakeLevel) $
        setPeerCID conn $ headerPeerCID header
    eplain <- decryptCrypt conn crypt level
    case eplain of
      Right (Plain _ pn fs) -> do
          rets <- mapM (processFrame conn level) fs
          when (and rets) $ addPeerPacketNumbers conn level pn
      Left err -> do
        putStrLn $ "processCryptPacket: " ++ show err
        statelessReset <- isStateLessreset conn header crypt
        if statelessReset then do
            putStrLn "Connection is reset statelessly"
            setCloseReceived conn
            clearThreads conn
          else
            return () -- fixme: sending statelss reset

processFrame :: Connection -> EncryptionLevel -> Frame -> IO Bool
processFrame _ _ Padding{} = return True
processFrame conn _ (Ack ackInfo _) = do
    let pns = fromAckInfo ackInfo
    mapM_ (releaseOutputRemoveAcks conn) pns
    return True
processFrame conn lvl (Crypto off cdat) = do
    case lvl of
      InitialLevel   -> do
          putCrypto conn $ InpHandshake lvl cdat off emptyToken
          return True
      RTT0Level -> do
          putStrLn $ "processFrame: invalid packet type " ++ show lvl
          return False
      HandshakeLevel
          | isClient conn -> do
              putCrypto conn $ InpHandshake lvl cdat off emptyToken
              return True
         | otherwise -> do
              control <- getServerController conn
              SendSessionTicket nst <- control $ PutClientFinished cdat
              -- aka sendCryptoData
              putOutput conn $ OutHndServerNST nst
              -- todo: sending "HandshakeDone" here
              ServerHandshakeDone <- control ExitServer
              clearServerController conn
              cryptoToken <- generateToken
              mgr <- getTokenManager conn
              token <- encryptToken mgr cryptoToken
              putOutput conn $ OutControl lvl [NewToken token]
              return True
      RTT1Level
        | isClient conn -> do
              control <- getClientController conn
              RecvSessionTicket   <- control $ PutSessionTicket cdat
              ClientHandshakeDone <- control ExitClient
              clearClientController conn
              return True
        | otherwise -> do
              putStrLn "processFrame: Short:Crypto for server"
              return False
processFrame conn _ (NewToken token) = do
    setNewToken conn token
    putStrLn "processFrame: NewToken"
    return True
processFrame _ _ (NewConnectionID _sn _ _cid _token)  = do
    -- fixme: register stateless token
    putStrLn $ "processFrame: NewConnectionID " ++ show _sn
    return True
processFrame conn _ (ConnectionCloseQUIC err ftyp reason) = do
    putInput conn $ InpTransportError err ftyp reason
    -- to cancel handshake
    putCrypto conn $ InpTransportError err ftyp reason
    setCloseSent conn
    setCloseReceived conn
    clearThreads conn
    return False
processFrame conn _ (ConnectionCloseApp err reason) = do
    putStrLn $ "processFrame: ConnectionCloseApp " ++ show err
    putInput conn $ InpApplicationError err reason
    -- to cancel handshake
    putCrypto conn $ InpApplicationError err reason
    setCloseSent conn
    setCloseReceived conn
    clearThreads conn
    return False
processFrame conn RTT0Level (Stream sid _off dat fin) = do
    -- fixme _off
    putInput conn $ InpStream sid dat
    when (fin && dat /= "") $ putInput conn $ InpStream sid ""
    return True
processFrame conn RTT1Level (Stream sid _off dat fin) = do
    -- fixme _off
    putInput conn $ InpStream sid dat
    when (fin && dat /= "") $ putInput conn $ InpStream sid ""
    return True
processFrame conn lvl Ping = do
    putOutput conn $ OutControl lvl []
    return True
{-
processFrame conn lvl HandshakeDone = do
    control <- getClientController conn
    ClientHandshakeDone <- control ExitClient
    clearClientController conn
    return True
-}
processFrame _ _ _frame        = do
    putStrLn $ "processFrame: " ++ show _frame
    return True

-- QUIC version 1 uses only short packets for stateless reset.
-- But we should check other packets, too.
isStateLessreset :: Connection -> Header -> Crypt -> IO Bool
isStateLessreset conn header Crypt{..}
  | myCID conn /= headerMyCID header = do
        params <- getPeerParameters conn
        case statelessResetToken params of
          Nothing -> return False
          mtoken  -> do
              let mtoken' = decodeStatelessResetToken cryptPacket
              return (mtoken == mtoken')
  | otherwise = return False
