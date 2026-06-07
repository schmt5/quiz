## End-to-end playtest seed: one confirmed moderator + a game with all five
## question types, opened and started so a run is live immediately.
##
##   mix run priv/repo/playtest_seed.exs
##
## Prints the login + join details at the end.

alias Quiz.{Accounts, Games, Play, Repo}
alias Quiz.Accounts.Scope

email = "playtest@example.com"
password = "playtest password!"

# Re-runnable: wipe any prior playtest user (cascades to games/questions/etc).
case Repo.get_by(Accounts.User, email: email) do
  nil -> :ok
  user -> Repo.delete!(user)
end

{:ok, user} = Accounts.register_user(%{name: "Playtest Host", email: email, password: password})
scope = Scope.for_user(user)

{:ok, game} = Games.create_game(scope, %{title: "Playtest Quiz", status: :draft})

questions = [
  %{
    type: :text_input,
    prompt: "Hauptstadt von Frankreich?",
    position: 1,
    data: %{solutions: [%{text: "Paris"}]}
  },
  %{
    type: :single_choice,
    prompt: "Welche Farbe hat der Himmel?",
    position: 2,
    data: %{choices: [%{text: "Blau", correct: true}, %{text: "Grün", correct: false}]}
  },
  %{
    type: :sequence,
    prompt: "Sortiere chronologisch (älteste zuerst)",
    position: 3,
    data: %{items: [%{text: "Antike"}, %{text: "Mittelalter"}, %{text: "Neuzeit"}]}
  },
  %{
    type: :matching,
    prompt: "Ordne Land und Hauptstadt zu",
    position: 4,
    data: %{
      pairs: [
        %{left_text: "Frankreich", right_text: "Paris"},
        %{left_text: "Japan", right_text: "Tokio"},
        %{left_text: "Brasilien", right_text: "Brasília"}
      ]
    }
  },
  %{
    type: :pin_on_image,
    prompt: "Markiere die Mitte des Bildes",
    position: 5,
    data: %{
      pin: %{
        image_key: "uploads/test/fixture.png",
        target_x: 0.5,
        target_y: 0.5,
        radius: 0.15
      }
    }
  }
]

for attrs <- questions do
  {:ok, _q} = Games.create_question(scope, Map.put(attrs, :game_id, game.id))
end

{:ok, game} = Play.open_run(scope, game)
{:ok, game} = Play.start_run(scope, game)

IO.puts("""

==== PLAYTEST READY ====
Login:      #{email}  /  #{password}
Game:       #{game.title}  (id #{game.id}, status #{game.status})
Moderator:  http://localhost:4000/games/#{game.id}/run
Correction: http://localhost:4000/games/#{game.id}/correction
Leaderboard:http://localhost:4000/games/#{game.id}/leaderboard
Join code:  #{game.join_code}
Play URL:   http://localhost:4000/play/#{game.join_code}
========================
""")
