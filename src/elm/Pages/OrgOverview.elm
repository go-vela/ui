module Pages.OrgOverview exposing (..)
import Nav exposing (viewOrgTabs)
import Vela exposing (Repo)
import Html
    exposing
        ( Html
        , a
        , button
        , details
        , div
        , footer
        , h1
        , h2
        , header
        , input
        , label
        , li
        , main_
        , nav
        , p
        , summary
        , text
        , ul
        )
import Html.Attributes
    exposing
        ( attribute
        , checked
        , class
        , classList
        , for
        , href
        , id
        , name
        , type_
        )
import Util
import Nav exposing (Msgs)
import Pages.Secrets.Model exposing (Msg)


eventEnum : List String
eventEnum =
    [ "all", "push", "pull_request", "tag", "deployment", "comment" ]


viewPinnedRepo : Repo -> Html msg
viewPinnedRepo repo =
    text repo


viewPinnedRepos : Html msg
viewPinnedRepos =
        div [] [
            div [] [
                viewPinnedRepo "Repo 1"
                , viewPinnedRepo "Repo 2"
                , viewPinnedRepo "Repo 3"
            ]
            ,div [] [
                viewPinnedRepo "Repo 4"
                , viewPinnedRepo "Repo 5"
                , viewPinnedRepo "Repo 67"
            ]
        ]

viewAuditLog : Html msg
viewAuditLog =
        div [ class "form-controls", class "build-filters", Util.testAttribute "build-filter" ] <|
            div [] [ text "Filter by Event:" ]
                :: List.map
                    (\e ->
                        div [ class "form-control" ]
                            [ input
                                [ type_ "radio"
                                , id <| "filter-" ++ e
                                , name "build-filter"
                                , Util.testAttribute <| "build-filter-" ++ e
                                , attribute "aria-label" <| "filter to show " ++ e ++ " events"
                                ]
                                []
                            , label
                                [ class "form-label"
                                , for <| "filter-" ++ e
                                ]
                                [ text <| String.replace "_" " " e ]
                            ]
                    )
                    eventEnum

view : Html msg
view =
    div [] [
        -- Pinned Repos Go Here
          -- Nothing like this currently probably exists
        h2 [ class "settings-title" ] [ text "Pinned Repos" ]
        -- 2 rows tall, 3 columns wide of pinned repos?
        , viewPinnedRepos
        , viewOrgTabs
        , viewAuditLog
    ]