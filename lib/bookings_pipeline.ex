defmodule BookingsPipeline do
  use Broadway

  @producer BroadwayRabbitMQ.Producer
  @producer_config [
    queue: "bookings_queue",
    declare: [durable: true],
    on_failure: :reject_and_requeue
  ]

  def start_link(_args) do
    opts = [
      name: BookingsPipeline,
      producer: [module: {@producer, @producer_config}],
      processors: [
        default: []
      ]
    ]

    Broadway.start_link(__MODULE__, opts)
  end

  def handle_message(_processor, message, _context) do
    %{data: %{event: event, user: user}} = message

    if Tickets.ticket_available?(event) do
      Tickets.create_ticket(user, event)
      Tickets.send_email(user)
      IO.inspect(message, label: "Message")
    else
      Broadway.Message.failed(message, "bookings-closed")
    end
  end

  def handle_failed(messages, _context) do
    IO.inspect(messages, label: "Failed messages")

    Enum.map(messages, fn
      %{status: {:failed, "bookings-closed"}} = message ->
        Broadway.Message.configure_ack(message, on_failure: :reject)

      message ->
        message
    end)
  end

  def prepare_messages(messages, _context) do
    messages
    |> parse_messages()
    |> add_users()
  end

  defp parse_messages(messages) do
    Enum.map(messages, &parse_message/1)
  end

  defp parse_message(message) do
    Broadway.Message.update_data(message, fn data ->
      [event, user_id] = String.split(data, ",")
      %{event: event, user_id: user_id}
    end)
  end

  defp add_users(messages) do
    users =
      messages
      |> Enum.map(& &1.data.user_id)
      |> Tickets.users_by_ids()

    Enum.map(messages, &add_user(&1, users))
  end

  defp add_user(message, users) do
    Broadway.Message.update_data(message, fn data ->
      user = Enum.find(users, &(&1.id == data.user_id))
      Map.put(data, :user, user)
    end)
  end
end
