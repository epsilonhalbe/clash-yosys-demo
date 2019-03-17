{-# LANGUAGE AllowAmbiguousTypes        #-}
{-# LANGUAGE BangPatterns               #-}
{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE QuasiQuotes                #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE BinaryLiterals             #-}
{-# LANGUAGE RankNTypes                 #-}
{-# LANGUAGE ViewPatterns               #-}
{-# LANGUAGE NamedFieldPuns             #-}
module Top where

import Button (button)

import Clash.Prelude

{-# ANN topEntity
  (Synthesize
    { t_name     = "calculator"
    , t_inputs   =
        [ PortName "clk"
        , PortName "pmod1"
        , PortName "pmod2"
        , PortName "pmod3"
        , PortName "pmod4"
        ]
    , t_output   = PortProduct "out"
        [ PortName "led1"
        , PortName "led2"
        , PortName "led3"
        , PortName "led4"
        , PortName "led5"
        ]
    }) #-}
topEntity
  :: Clock System Source
  -> Bit -> Bit -> Bit -> Bit
  -> Signal System (Bit, Bit, Bit, Bit, Bit)
topEntity clk pmod1 pmod2 pmod3 pmod4 =
  withClockReset clk (unsafeToAsyncReset (pure False)) $
    fmap fromOutput $
      calculator $
        toUpdates
          (button clk pmod1)
          (button clk pmod3)
          (button clk pmod4)

  where
    fromOutput o =
      ( number o ! 0
      , number o ! 1
      , number o ! 2
      , number o ! 3
      , isResult o
      )

data Update
  = Confirm
  | Push Bit
  deriving (Show)

toUpdates
  :: HiddenClockReset domain gated reset
  => Signal domain Bit
  -> Signal domain Bit
  -> Signal domain Bit
  -> Signal domain (Maybe Update)

toUpdates
  = liftA3 pick

  where
    pick confirm push0 push1
      | confirm == high = Just Confirm
      | push0 == high   = Just (Push 0)
      | push1 == high   = Just (Push 1)
      | otherwise       = Nothing

data Output
  = Output
      { number :: Unsigned 4
      , isResult :: Bit
      }
  deriving (Show)

calculator
  :: HiddenClockReset domain gated reset
  => Signal domain (Maybe Update)
  -> Signal domain Output

calculator =
  moore (flip (maybe id update)) view initialState

type Number
  = Unsigned 4

data State
  = State
      { step :: Step
      , firstNumber :: Number
      , secondNumber :: Number
      }
  deriving (Show)

data Step
  = EnteringFirstNumber
  | EnteringSecondNumber
  | ShowingResult
  deriving (Show)

nextStep :: Step -> Step
nextStep EnteringFirstNumber = EnteringSecondNumber
nextStep EnteringSecondNumber = ShowingResult
nextStep ShowingResult = EnteringFirstNumber

initialState :: State
initialState
  = State
      { step = EnteringFirstNumber
      , firstNumber = 0
      , secondNumber = 0
      }

view :: State -> Output
view State{step, firstNumber, secondNumber}
  = Output {number, isResult}

  where
    number
      = case step of
          EnteringFirstNumber -> firstNumber
          EnteringSecondNumber -> secondNumber
          ShowingResult -> firstNumber + secondNumber

    isResult
      = case step of
          ShowingResult -> high
          _ -> low

update :: Update -> State -> State
update update state
  = case update of
      Confirm ->
        state {step = nextStep (step state)}
      Push b  ->
        case step state of
          EnteringFirstNumber ->
            state {firstNumber = push b (firstNumber state)}
          EnteringSecondNumber ->
            state {secondNumber = push b (secondNumber state)}
          ShowingResult ->
            state

  where
    push b n = unpack (slice d2 d0 n ++# pack b)

main :: IO ()
main = print "hello world"