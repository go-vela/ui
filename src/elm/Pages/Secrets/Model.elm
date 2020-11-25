{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.Model exposing
    ( ManageSecretState(..)
    , Model
    , Msg(..)
    , PartialModel
    , SecretForm
    , defaultSecretUpdate
    , secretsResourceKey
    )

import Alerts exposing (Alert)
import Errors exposing (Error)
import Http
import Http.Detailed
import LinkHeader exposing (WebLink)
import Pages exposing (Page(..))
import RemoteData exposing (RemoteData(..), WebData)
import Toasty as Alerting exposing (Stack)
import Vela
    exposing
        ( Engine
        , Org
        , Repo
        , Secret
        , SecretType
        , Secrets
        , Session
        , Team
        )



-- TYPES


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a
        | velaAPI : String
        , session : Maybe Session
        , secretsModel : Model
        , toasties : Stack Alert
    }


{-| Model : record to hold page input arguments
-}
type alias Model =
    { org : Org
    , repo : Repo
    , team : Team
    , engine : Engine
    , type_ : SecretType
    , secrets : WebData Secrets
    , secret : WebData Secret
    , form : SecretForm
    , pager : List WebLink
    }



{- secretsResourceKey : takes Model returns maybe string for retrieving secrets based on type -}


secretsResourceKey : Model -> Maybe String
secretsResourceKey secretsModel =
    case secretsModel.type_ of
        Vela.OrgSecret ->
            Nothing

        Vela.RepoSecret ->
            Just secretsModel.repo

        Vela.SharedSecret ->
            Just secretsModel.team


{-| SecretForm : record to hold potential add/update secret fields
-}
type alias SecretForm =
    { name : String
    , value : String
    , events : List String
    , imageInput : String
    , images : List String
    , allowCommand : Bool
    }


defaultSecretUpdate : SecretForm
defaultSecretUpdate =
    SecretForm "" "" [] "" [] True



-- MSG


type Msg
    = OnChangeStringField String String
    | OnChangeEvent String Bool
    | AddImage String
    | RemoveImage String
    | OnChangeAllowCommand String
    | AddSecret Engine
    | UpdateSecret Engine
    | AddSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
    | UpdateSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
    | HandleError Error
    | AlertsUpdate (Alerting.Msg Alert)


type ManageSecretState
    = Choose
    | Add
    | Update
