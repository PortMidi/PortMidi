{- |
    Interface to PortMidi
-}
{-# LANGUAGE EmptyDataDecls #-}

module Sound.PortMidi (
  -- * Data Types
    PMError(..)
  , PMSuccess(..)
  , PMStream
  , DeviceInfo(..)
  , DeviceID
  , PMMsg(..)
  , PMEvent(..)
  -- * Constants
  , filterActive
  , filterSysex
  , filterClock
  , filterPlay
  , filterTick
  , filterFD
  , filterUndefined
  , filterReset
  , filterRealtime
  , filterNote
  , filterChannelAftertouch
  , filterPolyAftertouch
  , filterAftertouch
  , filterProgram
  , filterControl
  , filterPitchBend
  , filterMTC
  , filterSongPosition
  , filterSongSelect
  , filterTune
  , filterSystemCommon
  -- * PortMid functions
  , initialize
  , terminate
  , hasHostError
  , getErrorText
  , countDevices
  , getDefaultInputDeviceID
  , getDefaultOutputDeviceID
  , getDeviceInfo
  , openInput
  , openOutput
  , setFilter
  , channel
  , setChannelMask
  , abort
  , close
  , poll
  , readEvents
  , writeEvents
  , writeShort
  , writeSysEx
  -- * Time function
  , time
  --
  , encodeMsg
  , decodeMsg
  ) where


import Foreign
import Foreign.C

import Sound.PortMidi.DeviceInfo

data PMSuccess
  = NoError'NoData
  -- ^ Means no data when returned by 'poll', else means no error.
  | GotData
  -- ^ Returned by 'poll' only, means that data is available.
  deriving (Eq, Show)

instance Enum PMSuccess where
  fromEnum NoError'NoData = 0
  fromEnum GotData = 1
  toEnum 0 = NoError'NoData
  toEnum 1 = GotData
  toEnum x = error $ "PortMidi: PMSuccess toEnum out of bound " ++ show x

data PMError
  = HostError
  | InvalidDeviceId
  | InsufficientMemory
  | BufferTooSmall
  | BufferOverflow
  | BadPtr
  | BadData
  | InternalError
  | BufferMaxSize
  deriving (Eq, Show)

instance Enum PMError where
  fromEnum HostError = -10000
  fromEnum InvalidDeviceId = -9999
  fromEnum InsufficientMemory = -9998
  fromEnum BufferTooSmall = -9997
  fromEnum BufferOverflow = -9996
  fromEnum BadPtr = -9995
  fromEnum BadData = -9994
  fromEnum InternalError = -9993
  fromEnum BufferMaxSize = -9992
  toEnum (-10000) = HostError
  toEnum (-9999) = InvalidDeviceId
  toEnum (-9998) = InsufficientMemory
  toEnum (-9997) = BufferTooSmall
  toEnum (-9996) = BufferOverflow
  toEnum (-9995) = BadPtr
  toEnum (-9994) = BadData
  toEnum (-9993) = InternalError
  toEnum (-9992) = BufferMaxSize
  toEnum x = error $ "PortMidi: PMError toEnum out of bound " ++ show x

toPMError :: CInt -> Either PMError PMSuccess
toPMError n
  | isSuccess = Right $ toEnum $ fromIntegral n
  | otherwise = Left $ toEnum $ fromIntegral n
  where
    isSuccess = n == 0 || n == 1

data PortMidiStream
type PMStreamPtr = Ptr PortMidiStream
type PMStream = ForeignPtr PortMidiStream
type DeviceID = Int

(.<.) :: CLong -> Int -> CLong
(.<.) = shiftL

(.>.) :: CLong -> Int -> CLong
(.>.) = shiftR

filterActive, filterSysex, filterClock, filterPlay, filterTick, filterFD, filterUndefined, filterReset, filterRealtime, filterNote, filterChannelAftertouch, filterPolyAftertouch, filterAftertouch, filterProgram, filterControl, filterPitchBend, filterMTC, filterSongPosition, filterSongSelect, filterTune, filterSystemCommon :: CLong

filterActive = 1 .<. 0x0e
filterSysex = 1 .<. 0x00
filterClock = 1 .<. 0x08
filterPlay = (1 .<. 0x0A) .|. (1 .<. 0x0C) .|. (1 .<. 0x0B)
filterTick = 1 .<. 0x09
filterFD = 1 .<. 0x0D
filterUndefined = filterFD
filterReset = 1 .<. 0x0F
filterRealtime = filterActive .|. filterSysex .|. filterClock .|. filterPlay .|. filterUndefined .|. filterReset .|. filterTick
filterNote = (1 .<. 0x19) .|. (1 .<. 0x18)
filterChannelAftertouch = 1 .<. 0x1D
filterPolyAftertouch = 1 .<. 0x1A
filterAftertouch = filterChannelAftertouch .|. filterPolyAftertouch
filterProgram = 1 .<. 0x1C
filterControl = 1 .<. 0x1B
filterPitchBend = 1 .<. 0x1E
filterMTC = 1 .<. 0x01
filterSongPosition = 1 .<. 0x02
filterSongSelect = 1 .<. 0x03
filterTune = 1 .<. 0x06
filterSystemCommon = filterMTC .|. filterSongPosition .|. filterSongSelect .|. filterTune

data PMMsg
  =  PMMsg
  { status :: {-# UNPACK #-} !CLong
  , data1  :: {-# UNPACK #-} !CLong
  , data2  :: {-# UNPACK #-} !CLong
  } deriving (Eq, Show)

encodeMsg :: PMMsg -> CLong
encodeMsg (PMMsg s d1 d2) = ((d2 .&. 0xFF) .<. 16) .|. ((d1 .&. 0xFF) .<. 8) .|. (s .&. 0xFF)
decodeMsg :: CLong -> PMMsg
decodeMsg i = PMMsg (i .&. 0xFF) ((i .>. 8) .&. 0xFF) ((i .>. 16) .&. 0xFF)

type Timestamp = CULong

data PMEvent
  =  PMEvent
  { message   :: {-# UNPACK #-} !CLong
  , timestamp :: {-# UNPACK #-} !Timestamp
  } deriving (Eq, Show)

instance Storable PMEvent where
  sizeOf _ = sizeOf (0::CLong) * 2
  alignment _ = alignment (0::CLong)
  peek ptr = do
    m <- peekByteOff ptr 0
    t <- peekByteOff ptr (sizeOf m)
    return $ PMEvent m t
  poke ptr (PMEvent m t) = do
    pokeByteOff ptr 0 m
    pokeByteOff ptr (sizeOf m) t


foreign import ccall "portmidi.h Pm_Initialize" pm_Initialize :: IO CInt
initialize :: IO (Either PMError PMSuccess)
initialize = pm_Initialize >>= return . toPMError

foreign import ccall "portmidi.h Pm_Terminate" pm_Terminate :: IO CInt
terminate :: IO (Either PMError PMSuccess)
terminate = pm_Terminate >>= return . toPMError

foreign import ccall "portmidi.h Pm_HasHostError" pm_HasHostError :: PMStreamPtr -> IO CInt
hasHostError :: PMStream -> IO Bool
hasHostError = flip withForeignPtr (\stream -> pm_HasHostError stream >>= return . toEnum . fromIntegral)

foreign import ccall "portmidi.h Pm_GetErrorText" pm_GetErrorText :: CInt -> IO CString
getErrorText :: PMError -> IO String
getErrorText err = pm_GetErrorText (fromIntegral $ fromEnum err) >>= peekCString

foreign import ccall "portmidi.h Pm_CountDevices" pm_countDevices :: IO CInt
countDevices :: IO DeviceID
countDevices = pm_countDevices >>= return . fromIntegral

foreign import ccall "portmidi.h Pm_GetDefaultInputDeviceID" pm_GetDefaultInputDeviceID :: IO CInt
getDefaultInputDeviceID :: IO (Maybe DeviceID)
getDefaultInputDeviceID = do
  i <- pm_GetDefaultInputDeviceID
  return $ if i == -1 then Nothing else Just (fromIntegral i)
foreign import ccall "portmidi.h Pm_GetDefaultOutputDeviceID" pm_GetDefaultOutputDeviceID :: IO CInt
getDefaultOutputDeviceID :: IO (Maybe DeviceID)
getDefaultOutputDeviceID = do
  i <- pm_GetDefaultOutputDeviceID
  return $ if i == -1 then Nothing else Just (fromIntegral i)

foreign import ccall "portmidi.h Pm_GetDeviceInfo" pm_GetDeviceInfo :: CInt -> IO (Ptr ())
getDeviceInfo :: DeviceID -> IO DeviceInfo
getDeviceInfo deviceID = pm_GetDeviceInfo (fromIntegral deviceID) >>= peekDeviceInfo

foreign import ccall "portmidi.h Pm_OpenInput" pm_OpenInput :: Ptr PMStreamPtr -> CInt -> Ptr () -> CLong -> Ptr () -> Ptr () -> IO CInt
openInput :: DeviceID -> IO (Either PMError PMStream)
openInput inputDevice =
  with nullPtr (\ptr ->
    toPMError <$> pm_OpenInput ptr (fromIntegral inputDevice) nullPtr 0 nullPtr nullPtr >>= either
      (return . Left)
      (\_ -> do
        stream <- peek ptr
        Right <$> newForeignPtr_ stream))

foreign import ccall "portmidi.h Pm_OpenOutput" pm_OpenOutput :: Ptr PMStreamPtr -> CInt -> Ptr () -> CLong -> Ptr () -> Ptr () -> CLong -> IO CInt
openOutput :: DeviceID -> Int -> IO (Either PMError PMStream)
openOutput outputDevice latency =
  with nullPtr (\ptr -> do
    toPMError <$> pm_OpenOutput ptr (fromIntegral outputDevice) nullPtr 0 nullPtr nullPtr (fromIntegral latency) >>= either
      (return . Left)
      (\_ -> do
        stream <- peek ptr
        Right <$> newForeignPtr_ stream))

foreign import ccall "portmidi.h Pm_SetFilter" pm_SetFilter :: PMStreamPtr -> CLong -> IO CInt
setFilter :: PMStream -> CLong -> IO (Either PMError PMSuccess)
setFilter stream theFilter = withForeignPtr stream (fmap toPMError . flip pm_SetFilter theFilter)

channel :: Int -> CLong
channel i = 1 .<. i

foreign import ccall "portmidi.h Pm_SetChannelMask" pm_SetChannelMask :: PMStreamPtr -> CLong -> IO CInt
setChannelMask :: PMStream -> CLong -> IO (Either PMError PMSuccess)
setChannelMask stream mask = withForeignPtr stream (fmap toPMError . flip pm_SetChannelMask mask)

foreign import ccall "portmidi.h Pm_Abort" pm_Abort :: PMStreamPtr -> IO CInt
abort :: PMStream -> IO (Either PMError PMSuccess)
abort = flip withForeignPtr (fmap toPMError . pm_Abort)

foreign import ccall "portmidi.h Pm_Close" pm_Close :: PMStreamPtr -> IO CInt
close :: PMStream -> IO (Either PMError PMSuccess)
close = flip withForeignPtr (fmap toPMError . pm_Close)

foreign import ccall "portmidi.h Pm_Poll" pm_Poll :: PMStreamPtr -> IO CInt
poll :: PMStream -> IO (Either PMError PMSuccess)
poll = flip withForeignPtr (fmap toPMError . pm_Poll)

foreign import ccall "portmidi.h Pm_Read" pm_Read :: PMStreamPtr -> Ptr PMEvent -> CLong -> IO CInt
readEvents :: PMStream -> IO [PMEvent]
readEvents = flip withForeignPtr $ \s -> allocaArray (fromIntegral defaultBufferSize) $ \arr ->
  pm_Read s arr defaultBufferSize >>= flip peekArray arr . fromIntegral
 where
  defaultBufferSize = 256

foreign import ccall "portmidi.h Pm_Write" pm_Write :: PMStreamPtr -> Ptr PMEvent -> CLong -> IO CInt
writeEvents :: PMStream -> [PMEvent] -> IO (Either PMError PMSuccess)
writeEvents stream events = withForeignPtr stream (\s ->
  withArrayLen events (\len arr -> toPMError <$> pm_Write s arr (fromIntegral len)))

foreign import ccall "portmidi.h Pm_WriteShort" pm_WriteShort :: PMStreamPtr -> CULong -> CLong -> IO CInt
writeShort :: PMStream -> PMEvent -> IO (Either PMError PMSuccess)
writeShort stream (PMEvent msg t) = withForeignPtr stream (\s ->
  toPMError <$> pm_WriteShort s t msg)

foreign import ccall "portmidi.h Pm_WriteSysEx" pm_WriteSysEx :: PMStreamPtr -> CULong -> CString -> IO CInt
writeSysEx :: PMStream -> Timestamp -> String -> IO (Either PMError PMSuccess)
writeSysEx stream t str = withForeignPtr stream (\st ->
  withCAString str (\s -> toPMError <$> pm_WriteSysEx st t s))

foreign import ccall "porttime.h Pt_Time" time :: IO Timestamp
