module Layouts exposing (..)

import Layouts.Default


type Layout msg
    = Default Layouts.Default.Props


map : (msg1 -> msg2) -> Layout msg1 -> Layout msg2
map fn layout =
    case layout of
        Default data ->
            Default data
