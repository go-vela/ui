{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.OrgSecrets exposing
    ( Args
    , ManageSecretState(..)
    , Msg
    , view
    )

import Api
import Html
    exposing
        ( Html
        , a
        , code
        , div
        , em
        , h4
        , section
        , span
        , text
        )
import Html.Attributes
    exposing
        ( class
        , disabled
        , href
        , placeholder
        , value
        )
import Html.Events exposing (onClick, onInput)
import Http
import Http.Detailed
import List.Extra
import Pages exposing (Page(..))
import Pages.RepoSettings exposing (checkbox, radio)
import RemoteData exposing (RemoteData(..), WebData)
import Util exposing (largeLoader)
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
        , UpdateSecretPayload
        , buildUpdateSecretPayload
        , encodeUpdateSecret
        , nullSecret
        , secretTypeToString
        , toSecretType
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
    , secrets : WebData Secrets
    , manageState : ManageSecretState
    , selectedSecret : String
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
    { team : Team
    , name : String
    , value : String
    , type_ : SecretType
    , events : List String
    , imageInput : String
    , images : List String
    , allowCommand : Bool
    }



-- MSG


type alias SecretResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Secret ) -> msg


type alias SecretsResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ) -> msg


type Msg
    = OnChangeStringField String String
    | SelectSecret String
    | OnChangeEvent String Bool
    | AddImage String
    | RemoveImage String
    | OnChangeAllowCommand String
    | CancelUpdate
    | AddSecret
    | UpdateSecret


type ManageSecretState
    = Choose
    | Add
    | Update


{-| view : takes model and renders page for managing org secrets
-}
view : String -> Html Msg
view model =
    div [] []



-- let
--     secretsModel =
--         model
-- in
-- case secretsModel.secrets of
--     Success secrets ->
--         div []
--             [ div [ class "manage-secrets", Util.testAttribute "manage-secrets" ]
--                 [ div []
--                     [ Html.h2 [] [ text "Manage Secrets" ]
--                     -- , secretForm secretsModel secrets
--                     ]
--                 ]
--             -- , viewSecrets secrets
--             ]
--     _ ->
--         div [] [ Util.largeLoader ]
