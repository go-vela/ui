{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_.Artifacts exposing (..)

import Auth
import Components.Table
import Effect exposing (Effect)
import Html exposing (a, div, text, tr)
import Html.Attributes exposing (attribute, class, href)
import Http
import Http.Detailed
import Layouts
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Errors as Errors
import Utils.Helpers as Util
import Vela
import View exposing (View)


{-| page : takes user, shared model, route, and returns a build's artifacts page.
-}
page : Auth.User -> Shared.Model -> Route { org : String, repo : String, build : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


{-| toLayout : takes user, route, model, and passes a build's artifacts page info to Layouts.
-}
toLayout : Auth.User -> Route { org : String, repo : String, build : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Build
        { navButtons = []
        , utilButtons = []
        , helpCommands =
            [ { name = "View Build"
              , content =
                    "vela view build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/view"
              }
            , { name = "Approve Build"
              , content =
                    "vela approve build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/approve"
              }
            , { name = "Restart Build"
              , content =
                    "vela restart build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/restart"
              }
            , { name = "Cancel Build"
              , content =
                    "vela cancel build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/cancel"
              }
            ]
        , crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Just <| Route.Path.Org__Repo_ { org = route.params.org, repo = route.params.repo } )
            , ( "#" ++ route.params.build, Nothing )
            ]
        , org = route.params.org
        , repo = route.params.repo
        , build = route.params.build
        , toBuildPath =
            \build ->
                Route.Path.Org__Repo__Build__Artifacts
                    { org = route.params.org
                    , repo = route.params.repo
                    , build = build
                    }
        }



-- INIT


type alias Model =
    { build : WebData Vela.Build
    , artifacts : WebData (List Vela.Artifact)
    }


{-| init : takes shared model, route, and unit, and returns a model and effect.
-}
init : Shared.Model -> Route { org : String, repo : String, build : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { build = RemoteData.Loading
      , artifacts = RemoteData.Loading
      }
    , Effect.getBuildArtifacts
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetArtifactsResponse
        , org = route.params.org
        , repo = route.params.repo
        , build = route.params.build
        }
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = NoOp
    | DownloadTextArtifact { filename : String, content : String, map : String -> String }
    | GetArtifactsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Artifact ))


{-| update : takes current models, route info, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route { org : String, repo : String, build : String } -> Msg -> Model -> ( Model, Effect Msg )
update _ _ msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        DownloadTextArtifact options ->
            ( model
            , Effect.downloadFile options
            )

        GetArtifactsResponse response ->
            case response of
                Ok ( _, artifacts ) ->
                    ( { model | artifacts = RemoteData.Success artifacts }
                    , Effect.none
                    )

                Err error ->
                    ( { model | artifacts = Errors.toFailure error }
                    , Effect.none
                    )


{-| subscriptions : takes model and returns that there are no subscriptions.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes models, route, and creates the html for a build's artifacts page.
-}
view : Shared.Model -> Route { org : String, repo : String, build : String } -> Model -> View Msg
view shared _ model =
    let
        httpErrorToString error =
            case error of
                Http.BadUrl url ->
                    "Bad URL: " ++ url

                Http.Timeout ->
                    "Network timeout"

                Http.NetworkError ->
                    "Network error"

                Http.BadStatus statusCode ->
                    "HTTP " ++ String.fromInt statusCode

                Http.BadBody body ->
                    "Bad response: " ++ body

        noRowsView =
            text "No artifacts found for this build."

        artifactsTable =
            case model.artifacts of
                RemoteData.Success artifacts ->
                    Components.Table.view
                        (Components.Table.Config
                            "Artifacts"
                            "build-artifacts"
                            noRowsView
                            tableHeaders
                            (artifactsToRows shared.zone shared.time (List.sortBy .file_name artifacts))
                            Nothing
                            1
                        )

                RemoteData.Loading ->
                    div [ class "artifact-output" ] [ text "Loading artifacts..." ]

                RemoteData.Failure error ->
                    div [ class "artifact-output" ]
                        [ text ("Failed to load artifacts: " ++ httpErrorToString error) ]

                RemoteData.NotAsked ->
                    div [ class "artifact-output" ] [ text "No artifacts requested" ]
    in
    { title = "Artifacts"
    , body =
        [ div [ class "artifacts-layout" ]
            [ artifactsTable
            ]
        ]
    }


{-| artifactsToRows : takes list of artifacts and produces list of Table rows.
-}
artifactsToRows : Time.Zone -> Time.Posix -> List Vela.Artifact -> Components.Table.Rows Vela.Artifact Msg
artifactsToRows zone currentTime artifacts =
    artifacts
        |> List.map (\artifact -> Components.Table.Row artifact (viewArtifact zone currentTime))


{-| isArtifactExpired : checks if an artifact is expired (older than 7 days).
-}
isArtifactExpired : Time.Posix -> Int -> Bool
isArtifactExpired currentTime createdAt =
    let
        sevenDaysInSeconds =
            7 * 24 * 60 * 60

        expirationTime =
            createdAt + sevenDaysInSeconds

        currentTimeInSeconds =
            Time.posixToMillis currentTime // 1000
    in
    currentTimeInSeconds > expirationTime


{-| tableHeaders : returns table headers for artifacts table.
-}
tableHeaders : Components.Table.Columns
tableHeaders =
    [ ( Just "name", "name" )
    , ( Just "created-at-col", "created at" )
    , ( Just "expires-at-col", "expires at" )
    , ( Just "file-size-col", "file size" )
    ]


{-| viewArtifact : takes an artifact and renders a table row.
-}
viewArtifact : Time.Zone -> Time.Posix -> Vela.Artifact -> Html.Html Msg
viewArtifact zone currentTime artifact =
    let
        expired =
            isArtifactExpired currentTime artifact.created_at

        nameCell =
            if expired then
                div [ class "artifacts-expired" ]
                    [ Html.span
                        [ class "artifact-name-expired"
                        , attribute "style" "color: var(--color-text-secondary, #888);"
                        ]
                        [ text artifact.file_name ]
                    , Html.span
                        [ class "artifact-expired-label"
                        , attribute "style" "margin-left: 0.5rem; color: var(--color-text-secondary, #888); font-size: 0.875rem;"
                        ]
                        [ text "(Expired)" ]
                    ]

            else
                a
                    [ href artifact.presigned_url ]
                    [ text artifact.file_name ]
    in
    tr []
        [ Components.Table.viewItemCell
            { dataLabel = "name"
            , parentClassList = [ ( "name", True ) ]
            , itemClassList = [ ( "-block", True ) ]
            , children = [ nameCell ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "created-at"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| Util.humanReadableDateTimeWithDefault zone artifact.created_at ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "expires-at"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| Util.humanReadableDateTimeWithDefault zone (artifact.created_at + (4 * 24 * 60 * 60)) ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "file-size"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| Util.humanReadableBytesFormatter artifact.file_size ]
            }
        ]
