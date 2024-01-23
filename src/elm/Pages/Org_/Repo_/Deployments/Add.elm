{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Deployments.Add exposing (Model, Msg, page, view)

import Auth
import Effect exposing (Effect)
import Html exposing (div, h2, section, strong, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Shared
import Utils.Helpers as Util
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { utilButtons = []
        , navButtons = []
        }



-- INIT


type alias Model =
    { repo : WebData Vela.Repository
    , name : String
    , value : String
    , events : List String
    , images : List String
    , image : String
    , allowCommands : Bool
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { repo = RemoteData.Loading
      , name = ""
      , value = ""
      , events = [ "push" ]
      , images = []
      , image = ""
      , allowCommands = True
      }
    , Effect.getRepo
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetRepoResponse
        , org = route.params.org
        , repo = route.params.repo
        }
    )



-- UPDATE


type Msg
    = GetRepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
    | AddSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | NameOnInput String
    | ValueOnInput String
    | ImageOnInput String
    | EventOnCheck String Bool
    | AddImage String
    | RemoveImage String
    | AllowCommandsOnClick String
    | SubmitForm
    | AddAlertCopiedToClipboard String


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetRepoResponse response ->
            case response of
                Ok ( _, repo ) ->
                    ( { model | repo = RemoteData.succeed repo }
                    , Effect.none
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        AddSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    ( model
                    , Effect.addAlertSuccess
                        { content = secret.name ++ " added to repo secrets."
                        , addToastIfUnique = True
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        NameOnInput val ->
            ( { model | name = val }
            , Effect.none
            )

        ValueOnInput val ->
            ( { model | value = val }
            , Effect.none
            )

        ImageOnInput val ->
            ( { model | image = val }
            , Effect.none
            )

        EventOnCheck event val ->
            let
                updatedEvents =
                    if val then
                        model.events
                            |> List.append [ event ]
                            |> List.Extra.unique

                    else
                        model.events
                            |> List.filter ((/=) event)
            in
            ( { model | events = updatedEvents }
            , Effect.none
            )

        AddImage image ->
            ( { model
                | images =
                    model.images
                        |> List.append [ image ]
                        |> List.Extra.unique
                , image = ""
              }
            , Effect.none
            )

        RemoveImage image ->
            ( { model
                | images =
                    model.images
                        |> List.filter ((/=) image)
              }
            , Effect.none
            )

        AllowCommandsOnClick val ->
            ( model
                |> (\m -> { m | allowCommands = Util.yesNoToBool val })
            , Effect.none
            )

        SubmitForm ->
            let
                payload =
                    Vela.buildSecretPayload
                        { type_ = Just Vela.RepoSecret
                        , org = Just route.params.org
                        , repo = Just route.params.repo
                        , team = Nothing
                        , name = Util.stringToMaybe model.name
                        , value = Util.stringToMaybe model.value
                        , events = Just model.events
                        , images = Just model.images
                        , allowCommands = Just model.allowCommands
                        }

                body =
                    Http.jsonBody <| Vela.encodeSecretPayload payload
            in
            ( model
            , Effect.addRepoSecret
                { baseUrl = shared.velaAPI
                , session = shared.session
                , onResponse = AddSecretResponse
                , org = route.params.org
                , repo = route.params.repo
                , body = body
                }
            )

        AddAlertCopiedToClipboard contentCopied ->
            ( model
            , Effect.addAlertSuccess { content = contentCopied, addToastIfUnique = False }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    let
        msgs =
            { nameOnInput = NameOnInput
            , valueOnInput = ValueOnInput
            , imageOnInput = ImageOnInput
            , eventOnCheck = EventOnCheck
            , addImage = AddImage
            , removeImage = RemoveImage
            , allowCommandsOnClick = AllowCommandsOnClick
            , submit = SubmitForm
            , showCopyAlert = AddAlertCopiedToClipboard
            }
    in
    { title = route.params.org ++ "/" ++ route.params.repo ++ " Add Deployment"
    , body =
        [ div [ class "deployment-form" ]
            [ h2 [ class "deployment-header" ] [ text "Add Deployment" ]
            , case model.repo of
                RemoteData.Success repo ->
                    if repo.allow_deploy then
                        section []
                            []

                    else
                        section [ class "notice" ]
                            [ strong [] [ text "Deploy webhook for this repo must be enabled in settings" ]
                            ]

                _ ->
                    section [] []

            -- GitHub default is "production". If we support more SCMs, this line may need tweaking
            -- , viewValueInput "Target" deployment.target "provide the name for the target deployment environment (default: \"production\")"
            -- , viewValueInput "Ref" deployment.ref <| "provide the reference to deploy - this can be a branch, commit (SHA) or tag (default: " ++ branch ++ ")"
            -- , viewValueInput "Description" deployment.description "provide the description for the deployment (default: \"Deployment request from Vela\")"
            -- , viewValueInput "Task" deployment.task "Provide the task for the deployment (default: \"deploy:vela\")"
            -- , viewParameterInput deployment
            -- , viewHelp
            -- , viewSubmitButtons
            ]
        ]
    }
