{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.Model exposing
    ( AddSecretResponse
    , DeleteSecretResponse
    , DeleteSecretState(..)
    , Model
    , Msg(..)
    , PartialModel
    , SecretForm
    , SecretResponse
    , SecretsResponse
    , UpdateSecretResponse
    , defaultSecretUpdate
    )

import Auth.Session exposing (Session)
import Http
import Http.Detailed
import LinkHeader exposing (WebLink)
import Pages exposing (Page)
import RemoteData exposing (WebData)
import Vela exposing (Engine, Key, Org, Repo, Secret, SecretType, Secrets, Team)



-- TYPES


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a msg =
    { a
        | velaAPI : String
        , session : Session
        , page : Page
        , secretsModel : Model msg
    }


{-| Model : record to hold page input arguments
-}
type alias Model msg =
    { org : Org
    , repo : Repo
    , team : Team
    , engine : Engine
    , type_ : SecretType
    , repoSecrets : WebData Secrets
    , repoSecretsPager : List WebLink
    , orgSecrets : WebData Secrets
    , orgSecretsPager : List WebLink
    , sharedSecrets : WebData Secrets
    , sharedSecretsPager : List WebLink
    , secret : WebData Secret
    , form : SecretForm
    , secretResponse : SecretResponse msg
    , repoSecretsResponse : SecretsResponse msg
    , orgSecretsResponse : SecretsResponse msg
    , sharedSecretsResponse : SecretsResponse msg
    , addSecretResponse : AddSecretResponse msg
    , deleteSecretResponse : DeleteSecretResponse msg
    , updateSecretResponse : AddSecretResponse msg
    , pager : List WebLink
    , deleteState : DeleteSecretState
    }


{-| SecretForm : record to hold potential add/update secret fields
-}
type alias SecretForm =
    { name : String
    , value : String
    , events : List String
    , imageInput : String
    , images : List String
    , allowCommand : Bool
    , team : Key
    }


defaultSecretUpdate : SecretForm
defaultSecretUpdate =
    SecretForm "" "" [] "" [] True ""



-- MSG


type alias SecretResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Secret ) -> msg


type alias SecretsResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ) -> msg


type alias AddSecretResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Secret ) -> msg


type alias UpdateSecretResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Secret ) -> msg


type alias DeleteSecretResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg


type Msg
    = OnChangeStringField String String
    | OnChangeEvent String Bool
    | AddImage String
    | RemoveImage String
    | OnChangeAllowCommand String
    | AddSecret Engine
    | UpdateSecret Engine
    | DeleteSecret Engine
    | CancelDeleteSecret


type DeleteSecretState
    = NotAsked_
    | Confirm
    | Deleting
