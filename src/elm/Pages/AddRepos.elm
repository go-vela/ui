{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.AddRepos exposing (Actions, Model, view)

import Dict
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , code
        , details
        , div
        , h1
        , p
        , span
        , summary
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        )
import Html.Events exposing (onClick)
import RemoteData exposing (WebData)
import Routes exposing (Route(..))
import Search
    exposing
        ( filterRepo
        , repoSearchBarGlobal
        , repoSearchBarLocal
        , searchFilterGlobal
        , searchFilterLocal
        , shouldSearch
        )
import Svg.Attributes
import SvgBuilder
import Util
import Vela
    exposing
        ( CurrentUser
        , EnableRepo
        , EnableRepos
        , FavoriteRepo
        , Org
        , RepoSearchFilters
        , Repositories
        , Repository
        , Search
        , SourceRepositories
        , isFavorited
        )



-- TYPES


{-| Model : an abbreviated version of the main model
-}
type alias Model a =
    { a
        | user : WebData CurrentUser
        , sourceRepos : WebData SourceRepositories
        , sourceSearchFilters : RepoSearchFilters
    }


{-| Actions : record containing actions
-}
type alias Actions msg =
    { search : Search msg
    , enableRepo : EnableRepo msg
    , enableRepos : EnableRepos msg
    , toggleFavorite : FavoriteRepo msg
    }



-- VIEW


{-| view : takes model and renders account page for adding repos to overview
-}
view : Model a -> Actions msg -> Html msg
view model actions =
    let
        ( user, sourceRepos, sourceSearchFilters ) =
            ( model.user, model.sourceRepos, model.sourceSearchFilters )

        loading =
            div []
                [ h1 []
                    [ text "Loading your Repositories"
                    , span [ class "loading-ellipsis" ] []
                    ]
                , p []
                    [ text <|
                        "Hang tight while we grab the list of repositories that you have access to from Github. If you have access to "
                            ++ "a lot of organizations and repositories this might take a little while."
                    ]
                ]
    in
    case sourceRepos of
        RemoteData.Success repos ->
            div [ class "source-repos", Util.testAttribute "source-repos" ]
                [ repoSearchBarGlobal sourceSearchFilters actions.search
                , viewSourceRepos user repos sourceSearchFilters actions
                ]

        RemoteData.Loading ->
            loading

        RemoteData.NotAsked ->
            loading

        RemoteData.Failure _ ->
            div []
                [ p []
                    [ text <|
                        "There was an error fetching your available repositories... Click Refresh or try again later!"
                    ]
                ]


{-| viewSourceRepos : takes model and source repos and renders them based on user search
-}
viewSourceRepos : WebData CurrentUser -> SourceRepositories -> RepoSearchFilters -> Actions msg -> Html msg
viewSourceRepos user sourceRepos sourceSearchFilters actions =
    if shouldSearch <| searchFilterGlobal sourceSearchFilters then
        -- Search and render repos using the global filter
        searchReposGlobal user sourceSearchFilters sourceRepos actions.enableRepo actions.toggleFavorite

    else
        -- Render repos normally
        sourceRepos
            |> Dict.toList
            |> Util.filterEmptyLists
            |> List.map (\( org, repos_ ) -> viewSourceOrg sourceSearchFilters org repos_ actions)
            |> div [ class "repo-list" ]


{-| viewSourceOrg : renders the source repositories available to a user by org
-}
viewSourceOrg : RepoSearchFilters -> Org -> Repositories -> Actions msg -> Html msg
viewSourceOrg sourceSearchFilters org repos actions =
    let
        ( search, enableRepo, toggleFavorite ) =
            ( actions.search, actions.enableRepo, actions.toggleFavorite )

        ( repos_, filtered, content ) =
            if shouldSearch <| searchFilterLocal org sourceSearchFilters then
                -- Search and render repos using the global filter
                searchReposLocal org sourceSearchFilters repos enableRepo toggleFavorite

            else
                -- Render repos normally
                ( repos, False, List.map (viewSourceRepo enableRepo toggleFavorite) repos )
    in
    viewSourceOrgDetails sourceSearchFilters org repos_ filtered content search actions.enableRepos


{-| viewSourceOrgDetails : renders the source repositories by org as an html details element
-}
viewSourceOrgDetails : RepoSearchFilters -> Org -> Repositories -> Bool -> List (Html msg) -> Search msg -> EnableRepos msg -> Html msg
viewSourceOrgDetails sourceSearchFilters org repos filtered content search enableRepos =
    div [ class "org" ]
        [ details [ class "details", class "repo-item" ] <|
            viewSourceOrgSummary sourceSearchFilters org repos filtered content search enableRepos
        ]


{-| viewSourceOrgSummary : renders the source repositories details summary
-}
viewSourceOrgSummary : RepoSearchFilters -> Org -> Repositories -> Bool -> List (Html msg) -> Search msg -> EnableRepos msg -> List (Html msg)
viewSourceOrgSummary sourceSearchFilters org repos filtered content search enableRepos =
    summary [ class "summary", Util.testAttribute <| "source-org-" ++ org ]
        [ div [ class "org-header" ]
            [ text org
            , viewRepoCount repos
            ]
        ]
        :: div [ class "source-actions" ]
            [ repoSearchBarLocal sourceSearchFilters org search
            , enableReposButton org repos filtered enableRepos
            ]
        :: content


{-| viewSourceRepo : renders single repo within a list of org repos

    viewSourceRepo uses model.SourceRepositories and buildAddRepoElement to determine the state of each specific 'Enable' button

-}
viewSourceRepo : EnableRepo msg -> FavoriteRepo msg -> Repository -> Html msg
viewSourceRepo enableRepo toggleFavorite repo =
    let
        favorited =
            False
    in
    div [ class "-item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div [] [ text repo.name ]
        , div []
            [ enableRepoButton repo enableRepo toggleFavorite favorited
            ]
        ]


{-| viewSearchedSourceRepo : renders single repo when searching across all repos
-}
viewSearchedSourceRepo : EnableRepo msg -> FavoriteRepo msg -> Repository -> Bool -> Html msg
viewSearchedSourceRepo enableRepo toggleFavorite repo favorited =
    div [ class "-item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div []
            [ text <| repo.org ++ "/" ++ repo.name ]
        , div
            []
            [ enableRepoButton repo enableRepo toggleFavorite favorited
            ]
        ]


{-| viewRepoCount : renders the amount of repos available within an org
-}
viewRepoCount : List a -> Html msg
viewRepoCount repos =
    span [ class "repo-count", Util.testAttribute "source-repo-count" ] [ code [] [ text <| (String.fromInt <| List.length repos) ++ " repos" ] ]


{-| enableReposButton : takes List of repos and renders a button to enable them all at once, texts depends on user input filter
-}
enableReposButton : Org -> Repositories -> Bool -> EnableRepos msg -> Html msg
enableReposButton org repos filtered enableRepos =
    button [ class "-inverted", Util.testAttribute <| "add-org-" ++ org, onClick (enableRepos repos) ]
        [ text <|
            if filtered then
                "Enable Results"

            else
                "Enable All"
        ]


{-| enableRepoButton : builds action button for adding single repos
-}
enableRepoButton : Repository -> EnableRepo msg -> FavoriteRepo msg -> Bool -> Html msg
enableRepoButton repo enableRepo toggleFavorite favorited =
    case repo.enabled of
        RemoteData.NotAsked ->
            div [ class "add-repos-actions" ]
                [ button [ class "repo-enable-btn", class "-solid", onClick (enableRepo repo) ] [ text "Enable" ]
                ]

        RemoteData.Loading ->
            div [ class "add-repos-actions" ]
                [ div [ class "repo-enable-btn", class "repo-enable-enabling" ] [ span [ class "repo-enable-enabling-text" ] [ text "Enabling" ], span [ class "loading-ellipsis" ] [] ]
                ]

        RemoteData.Failure _ ->
            div [ class "add-repos-actions" ]
                [ div [ class "repo-enable-btn", class "repo-enable-failed", onClick (enableRepo repo) ] [ FeatherIcons.refreshCw |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Failed" ]
                ]

        RemoteData.Success enabledStatus ->
            if enabledStatus then
                div [ class "add-repos-actions" ]
                    [ SvgBuilder.star [ onClick <| toggleFavorite repo.org <| Just repo.name, Svg.Attributes.class "-cursor" ] favorited
                    , div [ class "repo-enable-btn", class "repo-enable-enabled" ]
                        [ FeatherIcons.check |> FeatherIcons.toHtml [ attribute "role" "img" ]
                        , span []
                            [ text "Enabled"
                            ]
                        ]
                    , a [ class "-btn", class "-solid", class "-view", class "add-repo-view", Routes.href <| Routes.RepositoryBuilds repo.org repo.name Nothing Nothing ]
                        [ text "View"
                        ]
                    ]

            else
                div [ class "repo-enable-btn", class "repo-enable-failed", onClick (enableRepo repo) ] [ FeatherIcons.refreshCw |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Failed" ]


{-| searchReposGlobal : takes source repositories and search filters and renders filtered repos
-}
searchReposGlobal : WebData CurrentUser -> RepoSearchFilters -> SourceRepositories -> EnableRepo msg -> FavoriteRepo msg -> Html msg
searchReposGlobal user filters repos enableRepo toggleFavorite =
    let
        filteredRepos =
            repos
                |> Dict.toList
                |> Util.filterEmptyLists
                |> List.map (\( _, repos_ ) -> repos_)
                |> List.concat
                |> List.filter (\repo -> filterRepo filters Nothing <| repo.org ++ "/" ++ repo.name)
    in
    div [ class "filtered-repos" ] <|
        -- Render the found repositories
        if not <| List.isEmpty filteredRepos then
            filteredRepos |> List.map (\repo -> viewSearchedSourceRepo enableRepo toggleFavorite repo <| isFavorited user <| repo.org ++ "/" ++ repo.name)

        else
            -- No repos matched the search
            [ div [ class "-no-repos" ] [ text "No results" ] ]


{-| searchReposLocal : takes repo search filters, the org, and repos and renders a list of repos based on user-entered text
-}
searchReposLocal : Org -> RepoSearchFilters -> Repositories -> EnableRepo msg -> FavoriteRepo msg -> ( Repositories, Bool, List (Html msg) )
searchReposLocal org filters repos enableRepo toggleFavorite =
    -- Filter the repos if the user typed more than 2 characters
    let
        filteredRepos =
            List.filter (\repo -> filterRepo filters (Just org) repo.name) repos
    in
    ( filteredRepos
    , True
    , if not <| List.isEmpty filteredRepos then
        List.map (viewSourceRepo enableRepo toggleFavorite) filteredRepos

      else
        [ div [ class "-no-repos" ] [ text "No results" ] ]
    )
