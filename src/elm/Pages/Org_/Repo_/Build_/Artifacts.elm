{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_.Artifacts exposing (..)

import Auth
import Effect exposing (Effect)
import Html exposing (a, code, div, small, text)
import Html.Attributes exposing (class, href)
import Http
import Http.Detailed
import Layouts
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Utils.Errors as Errors
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
toLayout _ route _ =
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


type Msg
    = NoOp
    | DownloadTextArtifact { filename : String, content : String, map : String -> String }
    | GetArtifactsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Artifact ))


{-| update : takes current models, route, message, and returns an updated model and effect.
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


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String, build : String } -> Model -> View Msg
view _ _ model =
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

        downloadLinks =
            case model.artifacts of
                RemoteData.Success artifacts ->
                    if List.length artifacts > 0 then
                        div [ class "artifacts-list" ]
                            (List.map viewArtifact (List.sortBy .file_name artifacts))

                    else
                        div [ class "no-artifacts" ] [ small [] [ code [] [ text "No artifacts found for this build." ] ] ]

                RemoteData.Loading ->
                    div [ class "artifact-output" ] [ text "Loading artifacts..." ]

                RemoteData.Failure error ->
                    div [ class "artifact-output" ]
                        [ text ("Failed to load artifacts: " ++ httpErrorToString error) ]

                RemoteData.NotAsked ->
                    div [ class "artifact-output" ] [ text "No artifacts requested" ]

        viewArtifact artifact =
            a
                [ class "artifact-output artifact-link"
                , href artifact.presigned_url
                ]
                [ text artifact.file_name ]
    in
    { title = "Artifacts"
    , body =
        [ div [ class "artifacts-layout" ]
            [ downloadLinks
            ]
        ]
    }
