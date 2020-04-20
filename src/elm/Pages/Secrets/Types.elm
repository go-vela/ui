{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.Types exposing
    ( Args
    , ManageSecretState(..)
    , Msg(..)
    , PartialModel
    , Secret
    , SecretResponse
    , SecretUpdate
    , SecretsResponse
    , defaultSecretUpdate
    )

import Http
import Http.Detailed
import Pages exposing (Page(..))
import RemoteData exposing (RemoteData(..), WebData)
import Vela
    exposing
        ( Key
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
type alias PartialModel a msg =
    { a
        | velaAPI : String
        , session : Maybe Session
        , secretsModel : Args msg
    }


{-| Args : record to hold page input arguments
-}
type alias Args msg =
    { org : Org
    , repo : Repo
    , team : Team
    , type_ : SecretType
    , secrets : WebData Secrets
    , secretUpdate : SecretUpdate
    , secretAdd : SecretUpdate
    , secretResponse : SecretResponse msg
    , secretsResponse : SecretsResponse msg
    }


type alias Secret =
    { id : Int
    , org : Org
    , repo : Repo
    , team : Key
    , name : String
    , type_ : SecretType
    , images : List String
    , events : List String
    , allowCommand : Bool
    }


{-| SecretUpdate : record to hold potential add/update secret fields
-}
type alias SecretUpdate =
    { name : String
    , value : String
    , events : List String
    , imageInput : String
    , images : List String
    , allowCommand : Bool
    }


defaultSecretUpdate : SecretUpdate
defaultSecretUpdate =
    SecretUpdate "" "" [ "push", "tag", "deploy" ] "" [] True



-- MSG


type alias SecretResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Secret ) -> msg


type alias SecretsResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ) -> msg


type Msg
    = OnChangeStringField String String
    | OnChangeEvent String Bool
    | AddImage String
    | RemoveImage String
    | OnChangeAllowCommand String
    | AddSecret


type ManageSecretState
    = Choose
    | Add
    | Update
