module Shared exposing (Flags, Model, Msg, decoder, init, update)

-- todo: these need to be refined, only expose what is needed

import Alerts exposing (..)
import Auth.Session exposing (..)
import Browser.Dom exposing (..)
import Browser.Events exposing (Visibility(..))
import Dict exposing (..)
import Effect exposing (Effect)
import Json.Decode as Decode exposing (..)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Pages exposing (..)
import RemoteData exposing (..)
import Route exposing (Route)
import Shared.Model
import Shared.Msg
import Time exposing (..)
import Toasty as Alerting
import Url exposing (..)
import Util exposing (..)
import Vela exposing (..)



-- INIT


type alias Model =
    Shared.Model.Model



-- todo: comments, what goes in here, why


type alias Flags =
    { isDev : Bool
    , velaAPI : String
    , velaFeedbackURL : String
    , velaDocsURL : String
    , velaTheme : String
    , velaRedirect : String
    , velaLogBytesLimit : Int
    , velaMaxBuildLimit : Int
    , velaScheduleAllowlist : String
    }


decoder : Decode.Decoder Flags
decoder =
    Decode.succeed Flags
        |> required "isDev" Decode.bool
        |> required "velaAPI" Decode.string
        |> required "velaFeedbackURL" Decode.string
        |> required "velaDocsURL" Decode.string
        |> required "velaTheme" Decode.string
        |> required "velaRedirect" Decode.string
        |> required "velaLogBytesLimit" Decode.int
        |> required "velaMaxBuildLimit" Decode.int
        |> required "velaScheduleAllowlist" Decode.string



-- todo: comments


init : Flags -> Route () -> Url -> ( Model, Effect Msg )
init flagsResult route url =
    -- todo: these need to be logically ordered (flags, session, user, data models, etc)
    ( { session = Unauthenticated
      , fetchingToken = String.length flagsResult.velaRedirect == 0
      , user = NotAsked
      , sourceRepos = NotAsked
      , velaAPI = flagsResult.velaAPI
      , velaFeedbackURL = flagsResult.velaFeedbackURL
      , velaDocsURL = flagsResult.velaDocsURL
      , velaRedirect = flagsResult.velaRedirect
      , velaLogBytesLimit = flagsResult.velaLogBytesLimit
      , velaMaxBuildLimit = flagsResult.velaMaxBuildLimit
      , velaScheduleAllowlist = Util.stringToAllowlist flagsResult.velaScheduleAllowlist
      , toasties = Alerting.initialState
      , zone = utc
      , time = millisToPosix 0
      , filters = Dict.empty
      , favoritesFilter = ""
      , repo = defaultRepoModel
      , entryURL = url
      , theme = stringToTheme flagsResult.velaTheme
      , shift = False
      , visibility = Visible
      , showHelp = False
      , showIdentity = False
      , buildMenuOpen = []
      , favicon = defaultFavicon
      , pipeline = defaultPipeline
      , templates = defaultPipelineTemplates

      -- todo: these need to be refactored with Msg
      -- , schedulesModel = initSchedulesModel
      -- , secretsModel = initSecretsModel
      -- , deploymentModel = initDeploymentsModel
      }
    , Effect.none
    )



-- UPDATE


type alias Msg =
    Shared.Msg.Msg



-- todo: vader: Effects


update : Route () -> Msg -> Model -> ( Model, Effect Msg )
update route msg model =
    case msg of
        Shared.Msg.ActualSharedMsg ->
            let
                _ =
                    Debug.log "Shared.Msg.SomeSharedMsg" "this is where we update the SHARED.Model"
            in
            ( model
            , Effect.none
            )

        Shared.Msg.ToggleFavorite org repo ->
            let
                _ =
                    0

                -- favorite =
                --     toFavorite org repo
                -- ( favorites, favorited ) =
                --     updateFavorites model.shared.user favorite
                -- payload : UpdateUserPayload
                -- payload =
                --     buildUpdateFavoritesPayload favorites
                -- body : Http.Body
                -- body =
                --     Http.jsonBody <| encodeUpdateUser payload
            in
            ( model
            , Effect.none
              -- todo: vader: implement Effects to get this to work
              -- , Api.try (RepoFavoritedResponse favorite favorited) (Api.updateCurrentUser model body)
            )

        Shared.Msg.SearchFavorites searchBy ->
            ( { model | favoritesFilter = searchBy }, Effect.none )

        Shared.Msg.NoOp ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS
-- todo: vader: move Main.elm subscriptions into shared


subscriptions : () -> Model -> Sub Msg
subscriptions route model =
    Sub.none
