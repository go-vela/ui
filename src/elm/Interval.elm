module Interval exposing (Interval(..), RefreshData)

import Vela exposing (BuildNumber, Org, Repo, Steps)


type Interval
    = OneSecond
    | OneSecondHidden
    | FiveSecond
    | FiveSecondHidden RefreshData


type alias RefreshData =
    { org : Org
    , repo : Repo
    , build_number : Maybe BuildNumber
    , steps : Maybe Steps
    }
