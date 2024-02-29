{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Account.SourceRepos exposing (..)

import Api.Api as Api
import Api.Operations
import Auth
import Components.Crumbs
import Components.Favorites
import Components.Nav
import Components.Search
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , details
        , div
        , main_
        , span
        , summary
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , classList
        , disabled
        )
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Utils.Errors
import Utils.Favorites as Favorites
import Utils.Helpers as Util
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared
        , update = update shared
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user shared)



-- LAYOUT


toLayout : Auth.User -> Shared.Model -> Model -> Layouts.Layout Msg
toLayout user shared model =
    Layouts.Default
        { helpCommands =
            [ { name = ""
              , content = "resources on this page not yet supported via the CLI"
              , docs = Nothing
              }
            ]
        }



-- INIT


type alias Model =
    { searchFilters : Dict Vela.Org String
    , sourceRepos : WebData Vela.SourceRepositories
    }


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( { searchFilters = Dict.empty
      , sourceRepos = shared.sourceRepos
      }
    , Effect.batch
        [ Effect.getCurrentUser {}
        , Effect.sendMsg (GetUserSourceRepos False)
        , Effect.focusOn { target = "global-search-input" }
        ]
    )



-- UPDATE


type Msg
    = NoOp
      -- SOURCE REPOS
    | GetUserSourceRepos Bool
    | GetUserSourceReposResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.SourceRepositories ))
    | EnableRepos (List Vela.Repository)
    | EnableRepo Vela.Repository
    | EnableRepoResponse { repo : Vela.Repository } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
    | UpdateSearchFilter Vela.Org String
      -- FAVORITES
    | ToggleFavorite Vela.Org (Maybe String)


update : Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update shared msg model =
    -- persist any source repos updates to the shared model
    (\( m, e ) ->
        ( m, Effect.batch [ e, Effect.updateSourceReposShared { sourceRepos = m.sourceRepos } ] )
    )
    <|
        case msg of
            NoOp ->
                ( model
                , Effect.none
                )

            -- SOURCE REPOS
            GetUserSourceRepos isReload ->
                ( { model
                    | sourceRepos =
                        if isReload || model.sourceRepos == RemoteData.NotAsked then
                            RemoteData.Loading

                        else
                            model.sourceRepos
                  }
                , Api.try
                    GetUserSourceReposResponse
                    (Api.Operations.getUserSourceRepos shared.velaAPIBaseURL shared.session)
                    |> Effect.sendCmd
                )

            GetUserSourceReposResponse response ->
                case response of
                    Ok ( _, repositories ) ->
                        ( { model
                            | sourceRepos = RemoteData.succeed repositories
                          }
                        , Effect.none
                        )

                    Err error ->
                        ( { model
                            | sourceRepos = Utils.Errors.toFailure error
                          }
                        , Effect.handleHttpError { httpError = error }
                        )

            EnableRepos repos ->
                ( model
                , repos
                    |> List.map EnableRepo
                    |> List.map Effect.sendMsg
                    |> Effect.batch
                )

            EnableRepo repo ->
                let
                    payload =
                        Vela.buildEnableRepoPayload repo

                    body =
                        Http.jsonBody <| Vela.encodeEnableRepository payload
                in
                ( { model
                    | sourceRepos = Vela.enableUpdate repo Vela.Enabling model.sourceRepos
                  }
                , Effect.enableRepo
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = EnableRepoResponse { repo = repo }
                    , body = body
                    }
                )

            EnableRepoResponse options response ->
                case response of
                    Ok ( _, repo ) ->
                        ( { model
                            | sourceRepos = Vela.enableUpdate repo Vela.Enabled model.sourceRepos
                          }
                        , Effect.batch
                            [ Effect.addAlertSuccess
                                { content = "Repo " ++ repo.full_name ++ " enabled."
                                , addToastIfUnique = True
                                , link = Nothing
                                }
                            , Effect.updateFavorites { org = repo.org, maybeRepo = Just repo.name, updateType = Favorites.Add }
                            ]
                        )

                    Err error ->
                        (case error of
                            Http.Detailed.BadStatus metadata _ ->
                                case metadata.statusCode of
                                    409 ->
                                        ( Vela.Enabled
                                        , Effect.addAlertSuccess
                                            { content = "Repo " ++ options.repo.full_name ++ " enabled."
                                            , addToastIfUnique = False
                                            , link = Nothing
                                            }
                                        )

                                    _ ->
                                        ( Vela.Failed, Effect.handleHttpError { httpError = error } )

                            _ ->
                                ( Vela.Failed, Effect.handleHttpError { httpError = error } )
                        )
                            |> Tuple.mapFirst (\enabled -> Vela.enableUpdate options.repo enabled model.sourceRepos)
                            |> Tuple.mapFirst (\_ -> { model | sourceRepos = Utils.Errors.toFailure error })

            UpdateSearchFilter org searchBy ->
                ( { model
                    | searchFilters =
                        Dict.update org (\_ -> Just searchBy) model.searchFilters
                  }
                , Effect.none
                )

            -- FAVORITES
            ToggleFavorite org maybeRepo ->
                ( model
                , Effect.updateFavorites { org = org, maybeRepo = maybeRepo, updateType = Favorites.Toggle }
                )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route () -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( "Account", Nothing )
            , ( "Source Repositories", Nothing )
            ]
    in
    { title = "Source Repos"
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons =
                [ button
                    [ classList
                        [ ( "button", True )
                        , ( "-outline", True )
                        ]
                    , onClick (GetUserSourceRepos True)
                    , disabled (model.sourceRepos == RemoteData.Loading)
                    , Util.testAttribute "refresh-source-repos"
                    ]
                    [ case model.sourceRepos of
                        RemoteData.Loading ->
                            text "Loading…"

                        _ ->
                            text "Refresh List"
                    ]
                ]
            , crumbs = Components.Crumbs.view route.path crumbs
            }
        , main_ [ class "content-wrap" ]
            [ div [ Util.testAttribute "source-repos" ]
                [ Components.Search.viewRepoSearchBarGlobal model.searchFilters UpdateSearchFilter
                , viewSourceRepos shared model
                ]
            ]
        ]
    }


{-| viewSourceRepos : takes model and source repos and renders them based on user search
-}
viewSourceRepos : Shared.Model -> Model -> Html Msg
viewSourceRepos shared model =
    case model.sourceRepos of
        RemoteData.Success repos ->
            if Components.Search.shouldSearch <| Components.Search.searchFilterGlobal model.searchFilters then
                searchReposGlobal shared model repos EnableRepo ToggleFavorite

            else
                repos
                    |> Dict.toList
                    |> Util.filterEmptyLists
                    |> List.map (\( org, repos_ ) -> viewSourceOrg shared.user model.searchFilters org repos_)
                    |> span []

        RemoteData.Loading ->
            viewLoadingSourceOrgs

        RemoteData.NotAsked ->
            viewLoadingSourceOrgs

        RemoteData.Failure _ ->
            viewErrorSourceOrg


{-| viewLoadingSourceOrgs : renders 8 source org loading skeletons
-}
viewLoadingSourceOrgs : Html Msg
viewLoadingSourceOrgs =
    span [] <|
        List.Extra.initialize 8 viewLoadingSourceOrg


{-| viewLoadingSourceOrg : renders a loading indicator in the form of a source org skeleton
-}
viewLoadingSourceOrg : Int -> Html Msg
viewLoadingSourceOrg idx =
    let
        icon =
            FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml []

        content =
            if idx == 0 then
                span []
                    [ text "Loading all source control repositories you have access to, this may take awhile"
                    , span [ class "loading-ellipsis" ] []
                    ]

            else
                text ""

        animation =
            div [ class "loading-shimmer" ] []
    in
    div [ class "loading-skeleton" ]
        [ animation
        , div []
            [ icon
            , content
            ]
        ]


{-| viewErrorSourceOrg : renders an error in the form of a source org when unable to fetch source repositories
-}
viewErrorSourceOrg : Html Msg
viewErrorSourceOrg =
    let
        icon =
            FeatherIcons.x |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml []

        content =
            text "There was an error fetching your available repositories, please refresh or try again later!"
    in
    div [ class "loading-skeleton", Util.testAttribute "source-repos-failed" ]
        [ div []
            [ icon
            , content
            ]
        ]


{-| viewSourceOrg : renders the source repositories available to a user by org
-}
viewSourceOrg :
    WebData Vela.CurrentUser
    -> Dict Vela.Org String
    -> Vela.Org
    -> List Vela.Repository
    -> Html Msg
viewSourceOrg user filters org repos =
    let
        ( repos_, filtered, content ) =
            if Components.Search.shouldSearch <| Components.Search.searchFilterLocal org filters then
                searchReposLocal user org filters repos EnableRepo ToggleFavorite

            else
                ( repos, False, List.map (viewSourceRepo user EnableRepo ToggleFavorite) repos )
    in
    viewSourceOrgDetails filters org repos_ filtered content UpdateSearchFilter EnableRepos


{-| viewSourceOrgDetails : renders the source repositories by org as an html details element
-}
viewSourceOrgDetails :
    Dict Vela.Org String
    -> Vela.Org
    -> List Vela.Repository
    -> Bool
    -> List (Html msg)
    -> Components.Search.Search msg
    -> (List Vela.Repository -> msg)
    -> Html msg
viewSourceOrgDetails filters org repos filtered content search enableRepos =
    details [ class "details", class "-with-border" ] <|
        viewSourceOrgSummary filters org repos filtered content search enableRepos


{-| viewSourceOrgSummary : renders the source repositories details summary
-}
viewSourceOrgSummary :
    Dict Vela.Org String
    -> Vela.Org
    -> List Vela.Repository
    -> Bool
    -> List (Html msg)
    -> Components.Search.Search msg
    -> (List Vela.Repository -> msg)
    -> List (Html msg)
viewSourceOrgSummary filters org repos filtered content search enableRepos =
    summary [ class "summary", Util.testAttribute <| "source-org-" ++ org ]
        [ text org
        , viewRepoCount repos
        , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
        ]
        :: div [ class "form-controls", class "-no-x-pad" ]
            [ Components.Search.viewRepoSearchBarLocal filters org search
            , enableReposButton org repos filtered enableRepos
            ]
        :: content


{-| viewSourceRepo : renders single repo within a list of org repos
viewSourceRepo uses model.sourceRepos and enableRepoButton to determine the state of each specific 'Enable' button
-}
viewSourceRepo :
    WebData Vela.CurrentUser
    -> (Vela.Repository -> msg)
    -> Favorites.UpdateFavorites msg
    -> Vela.Repository
    -> Html msg
viewSourceRepo user enableRepo toggleFavorite repo =
    div [ class "item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div [] [ text repo.name ]
        , enableRepoButton repo enableRepo toggleFavorite user
        ]


{-| viewSearchedSourceRepo : renders single repo when searching across all repos
-}
viewSearchedSourceRepo : (Vela.Repository -> msg) -> Favorites.UpdateFavorites msg -> Vela.Repository -> WebData Vela.CurrentUser -> Html msg
viewSearchedSourceRepo enableRepo toggleFavorite repo user =
    div [ class "item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div []
            [ text <| repo.org ++ "/" ++ repo.name ]
        , enableRepoButton repo enableRepo toggleFavorite user
        ]


{-| viewRepoCount : renders the amount of repos available within an org
-}
viewRepoCount : List a -> Html msg
viewRepoCount repos =
    span [ class "repo-count", Util.testAttribute "source-repo-count" ] [ text <| (String.fromInt <| List.length repos) ++ " repos" ]


{-| enableReposButton : takes List of repos and renders a button to enable them all at once, texts depends on user input filter
-}
enableReposButton : Vela.Org -> List Vela.Repository -> Bool -> (List Vela.Repository -> msg) -> Html msg
enableReposButton org repos filtered enableRepos =
    button [ class "button", class "-outline", Util.testAttribute <| "enable-org-" ++ org, onClick (enableRepos repos) ]
        [ text <|
            if filtered then
                "Enable Results"

            else
                "Enable All"
        ]


{-| enableRepoButton : builds action button for enabling single repos
-}
enableRepoButton : Vela.Repository -> (Vela.Repository -> msg) -> Favorites.UpdateFavorites msg -> WebData Vela.CurrentUser -> Html msg
enableRepoButton repo enableRepo toggleFavorite user =
    case repo.enabled of
        Vela.Disabled ->
            button
                [ class "button"
                , Util.testAttribute <| String.join "-" [ "enable", repo.org, repo.name ]
                , onClick (enableRepo repo)
                ]
                [ text "Enable" ]

        Vela.Enabling ->
            button
                [ class "button"
                , class "-outline"
                , class "-loading"
                , Util.testAttribute <| String.join "-" [ "loading", repo.org, repo.name ]
                ]
                [ text "Enabling", span [ class "loading-ellipsis" ] [] ]

        Vela.Enabled ->
            div [ class "buttons" ]
                [ Components.Favorites.viewStarToggle
                    { msg = toggleFavorite
                    , user = user
                    , org = repo.org
                    , repo = repo.name
                    }
                , button
                    [ class "button"
                    , class "-outline"
                    , class "-success"
                    , attribute "tabindex" "-1" -- in this scenario we are merely showing state, this is not interactive
                    , Util.testAttribute <| String.join "-" [ "enabled", repo.org, repo.name ]
                    ]
                    [ FeatherIcons.check |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Enabled" ]
                , a
                    [ class "button"
                    , Util.testAttribute <| String.join "-" [ "view", repo.org, repo.name ]
                    , Route.Path.href <| Route.Path.Org_Repo_ { org = repo.org, repo = repo.name }
                    ]
                    [ text "View" ]
                ]

        Vela.ConfirmDisable ->
            div [ class "buttons" ]
                [ Components.Favorites.viewStarToggle
                    { msg = toggleFavorite
                    , user = user
                    , org = repo.org
                    , repo = repo.name
                    }
                , button
                    [ class "button"
                    , class "-outline"
                    , class "-success"
                    , attribute "tabindex" "-1" -- in this scenario we are merely showing state, this is not interactive
                    , Util.testAttribute <| String.join "-" [ "enabled", repo.org, repo.name ]
                    ]
                    [ FeatherIcons.check |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Really Disable?" ]
                , a
                    [ class "button"
                    , Util.testAttribute <| String.join "-" [ "view", repo.org, repo.name ]
                    , Route.Path.href <| Route.Path.Org_Repo_ { org = repo.org, repo = repo.name }
                    ]
                    [ text "View" ]
                ]

        Vela.Disabling ->
            button
                [ class "button"
                , class "-outline"
                , class "-loading"
                , Util.testAttribute <| String.join "-" [ "loading", repo.org, repo.name ]
                ]
                [ text "Disabling", span [ class "loading-ellipsis" ] [] ]

        Vela.Failed ->
            button
                [ class "button"
                , class "-outline"
                , class "-failure"
                , class "-animate-rotate"
                , Util.testAttribute <| String.join "-" [ "failed", repo.org, repo.name ]
                , onClick (enableRepo repo)
                ]
                [ FeatherIcons.refreshCw |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Failed" ]


{-| searchReposGlobal : takes source repositories and search filters and renders filtered repos
-}
searchReposGlobal : Shared.Model -> Model -> Vela.SourceRepositories -> (Vela.Repository -> msg) -> Favorites.UpdateFavorites msg -> Html msg
searchReposGlobal shared model repos enableRepo toggleFavorite =
    let
        ( user, filters ) =
            ( shared.user, model.searchFilters )

        filteredRepos =
            repos
                |> Dict.toList
                |> Util.filterEmptyLists
                |> List.concatMap (\( _, repos_ ) -> repos_)
                |> List.filter (\repo -> Components.Search.filterRepo filters Nothing <| repo.org ++ "/" ++ repo.name)
    in
    div [ class "filtered-repos" ] <|
        if not <| List.isEmpty filteredRepos then
            filteredRepos |> List.map (\repo -> viewSearchedSourceRepo enableRepo toggleFavorite repo user)

        else
            [ div [ class "item" ] [ text "No results" ] ]


{-| searchReposLocal : takes repo search filters, the org, and repos and renders a list of repos based on user-entered text
-}
searchReposLocal :
    WebData Vela.CurrentUser
    -> Vela.Org
    -> Dict Vela.Org String
    -> List Vela.Repository
    -> (Vela.Repository -> msg)
    -> Favorites.UpdateFavorites msg
    -> ( List Vela.Repository, Bool, List (Html msg) )
searchReposLocal user org filters repos enableRepo toggleFavorite =
    let
        filteredRepos =
            List.filter (\repo -> Components.Search.filterRepo filters (Just org) repo.name) repos
    in
    ( filteredRepos
    , True
    , if not <| List.isEmpty filteredRepos then
        List.map (viewSourceRepo user enableRepo toggleFavorite) filteredRepos

      else
        [ div [ class "item" ] [ text "No results" ] ]
    )
