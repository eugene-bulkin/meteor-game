@Games = new Meteor.Collection("games")

formatBoard = (game) ->
  disabled = if not isYourTurn game then ' class="disabled" disabled="disabled"' else ''
  result = '<table class="game-board">'
  for row, i in game.board.board
    result += '<tr>'
    for col, j in row
      result += '<td>'
      result += switch col
        when 0 then "<button value='#{i * 3 + j}'#{disabled}></button>"
        when 1 then 'X'
        when 2 then 'O'
      result += '</td>'
    result += '</tr>'
  result += '</table>'
  result

getLines = (rows) ->
  diag1 = [0,1,2].map (i) -> rows[i][i]
  diag2 = [0,1,2].map (i) -> rows[i][2-i]
  cols = [0,1,2].map (i) -> rows.reduce(((l,r) -> l.concat(r)),[]).filter((v,j) -> j % 3 is i)
  rows.concat(cols.concat [diag1, diag2])

isSolved = (board) ->
  # check if winner already determined
  if board.turn is -1
    return true
  lines = getLines board.board
  for l in lines
    if l.every((v) -> v is 1) or l.every((v) -> v is 2)
      return true
  if board.total is 9
    return true
  false

isYourTurn = (game) ->
  curPlayer = game.players.indexOf Meteor.userId()
  game.board.turn is curPlayer

getWinner = (game) ->
  lines = getLines game.board.board
  for l in lines
    if l.every((v) -> v is 1)
      return game.players[0]
    if l.every((v) -> v is 2)
      return game.players[1]
  return null

makeBoard = () ->
  (0 for i in [1..3] for j in [1..3])

nameOf = (user) ->
  user.profile?.name || user.emails?[0].address || user._id

if Meteor.isClient
  # Users template
  Template.users.helpers {
    users: () ->
      Meteor.users.find({_id: {$ne: Meteor.userId()}}, {username: 1, emails: 1, profile: 1}).fetch()
  }
  Template.users.events = {
    'click button': (e) ->
      otherId = e.currentTarget.value
      if otherId isnt Meteor.userId()
        Games.insert {
          players: [Meteor.userId(), otherId],
          board: {
            turn: 0,
            balance: 0,
            total: 0,
            board: makeBoard()
          },
          winner: -1
        }
  }

  Handlebars.registerHelper 'nameOf', (user) ->
    nameOf user

  Handlebars.registerHelper 'formatBoard', (board) ->
    new Handlebars.SafeString(formatBoard board)

  # Games template
  Template.games.helpers {
    games: () ->
      Games.find({players: Meteor.userId()}).fetch()
    isYourTurn: (game) ->
      isYourTurn game
    isSolved: (board) ->
      console.log isSolved board
      isSolved board
    getWinnerName: (game) ->
      nameOf Meteor.users.findOne({_id: getWinner game})
  }

  Template.games.events = {
    'click button': (e) ->
      gameId = $(e.currentTarget).parents('div').attr('id').replace('game-','')
      curGame = Games.findOne({'_id': gameId})
      curPlayer = curGame.players.indexOf Meteor.userId()
      board = curGame.board
      if board.turn is curPlayer
        spot = +e.currentTarget.value
        board.board[~~(spot / 3)][spot % 3] = curPlayer + 1
        board.turn = 1 - board.turn
        board.balance += Math.pow(-1, curPlayer)
        board.total += 1
        if isSolved board
          board.turn = -1
          winner = -1
          winningPlayer = getWinner curGame
          if winningPlayer
            winner = 1 + curGame.players.indexOf winningPlayer
          else
            winner = 0
        console.log board
        Games.update({'_id': gameId}, {$set: { board: board, winner: winner }})
  }

  Template.header.helpers {
    getRecord: () ->
      uid = Meteor.userId()
      games = Games.find({players: uid}, {_id: 0, players: 1, winner: 1}).fetch()
      record = [0,0,0]
      for game in games
        players = game.players
        winner = game.winner
        if winner is 0 then record[2] += 1
        else if winner is -1 then continue
        else
          if winner is 1 + players.indexOf Meteor.userId() then record[0] += 1
          else record[1] += 1
      return record.join '-'
  }

if Meteor.isServer
  Meteor.startup ->
    # stuff here