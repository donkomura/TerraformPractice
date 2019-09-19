package functions

import (
	"bytes"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
  "math/rand"
)

// PubSubMessage : published message from Cloud Pub/Sub
type PubSubMessage struct {
	Data []byte `json:"data"`
}

// SubscribedMessage  | subscribed message from Cloud Pub/Sub
// Mention						:: ["channel", "here"] (empty: plane text)
// Channel						:: specify the channel to send messages
type SubscribedMessage struct {
	Mention string `json:"mention,omitempty"`
	Channel string `json:"channel"`
}

// DecodeMessage : decoding published message from Cloud Pub/Sub
func (msg PubSubMessage) DecodeMessage() (msgData SubscribedMessage, err error) {
	if err = json.Unmarshal(msg.Data, &msgData); err != nil {
		log.Printf("Message[%v] ... Could not decode subscribing data: %v", msg, err)
		if e, ok := err.(*json.SyntaxError); ok {
			log.Printf("syntax error at byte offset %d", e.Offset)
		}
		return
	}
	return
}

// SlackNotification : entry point
func SlackNotification(ctx context.Context, m PubSubMessage) error {
	msg, err := m.DecodeMessage()
	if err != nil {
		log.Fatal(err)
		return err
	}

	var webhookURL = os.Getenv("SLACK_WEBHOOK_URL")
	err = postMessage("meshi-bot", msg.Mention, msg.Channel, webhookURL)
	if err != nil {
		log.Fatal(err)
		return err
	}

	return nil
}

func postMessage(name string, mention string, channel string, webhookURL string) error {
  meal := [3] string{"ラーメン", "からあげ定食", "ピザ"}
  msg := "<!" + mention + ">\n" + meal[rand.Intn(3)]
	jsonStr := `{"channel":"` + channel + `","username":"` + name + `","text":"` + msg + `"}`

	req, err := http.NewRequest(
		"POST",
		webhookURL,
		bytes.NewBuffer([]byte(jsonStr)),
	)
	if err != nil {
		return err
	}

	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}

	defer resp.Body.Close()
	return nil
}
