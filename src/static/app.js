document.addEventListener("DOMContentLoaded", () => {
  const activitiesList = document.getElementById("activities-list");
  const activitySelect = document.getElementById("activity");
  const signupForm = document.getElementById("signup-form");
  const messageDiv = document.getElementById("message");

  // Function to fetch activities from API
  async function fetchActivities() {
    try {
      const response = await fetch("/activities");
      const activities = await response.json();

      // Clear loading message
      activitiesList.innerHTML = "";

      // Clear and reset activity select to avoid duplicate options
      activitySelect.innerHTML = '<option value="">-- Select an activity --</option>';

      // Populate activities list
      Object.entries(activities).forEach(([name, details]) => {
        const activityCard = document.createElement("div");
        activityCard.className = "activity-card";

        const spotsLeft = details.max_participants - details.participants.length;

        activityCard.innerHTML = `
          <h4>${name}</h4>
          <p>${details.description}</p>
          <p><strong>Schedule:</strong> ${details.schedule}</p>
          <p class="availability"><strong>Availability:</strong> ${spotsLeft} spots left</p>
        `;

        // Add participants section
        const participantsDiv = document.createElement("div");
        participantsDiv.className = "participants-list";

        const participantsHeader = document.createElement("h5");
        participantsHeader.textContent = "Participants";
        participantsDiv.appendChild(participantsHeader);

        const ul = document.createElement("ul");

        function renderNoParticipants() {
          ul.innerHTML = "";
          const li = document.createElement("li");
          li.textContent = "No participants yet";
          li.className = "no-participants";
          ul.appendChild(li);
        }

        if (details.participants && details.participants.length > 0) {
          details.participants.forEach((p) => {
            const li = document.createElement("li");
            li.className = "participant-item";

            const span = document.createElement("span");
            span.className = "participant-email";
            span.textContent = p;

            const btn = document.createElement("button");
            btn.className = "delete-btn";
            btn.setAttribute("aria-label", `Remove ${p}`);
            btn.innerHTML = "✖";

            // Delete handler
            btn.addEventListener("click", async () => {
              // disable while processing
              btn.disabled = true;
              try {
                const res = await fetch(
                  `/activities/${encodeURIComponent(name)}/signup?email=${encodeURIComponent(p)}`,
                  { method: "DELETE" }
                );
                if (res.ok) {
                  // remove from DOM
                  li.remove();
                  // update local details and availability display
                  const idx = details.participants.indexOf(p);
                  if (idx > -1) details.participants.splice(idx, 1);

                  const availabilityEl = activityCard.querySelector(".availability");
                  const newSpots = details.max_participants - details.participants.length;
                  availabilityEl.innerHTML = `<strong>Availability:</strong> ${newSpots} spots left`;

                  // if no participants left, show placeholder
                  if (!details.participants.length) {
                    renderNoParticipants();
                  }
                } else {
                  const err = await res.json().catch(()=>({detail: 'Erreur'}));
                  alert(err.detail || "Failed to remove participant");
                  btn.disabled = false;
                }
              } catch (e) {
                console.error("Error removing participant:", e);
                alert("Failed to remove participant. Please try again.");
                btn.disabled = false;
              }
            });

            li.appendChild(span);
            li.appendChild(btn);
            ul.appendChild(li);
          });
        } else {
          renderNoParticipants();
        }

        participantsDiv.appendChild(ul);
        activityCard.appendChild(participantsDiv);

        activitiesList.appendChild(activityCard);

        // Add option to select dropdown
        const option = document.createElement("option");
        option.value = name;
        option.textContent = name;
        activitySelect.appendChild(option);
      });
    } catch (error) {
      activitiesList.innerHTML = "<p>Failed to load activities. Please try again later.</p>";
      console.error("Error fetching activities:", error);
    }
  }

  // Handle form submission
  signupForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    const email = document.getElementById("email").value;
    const activity = document.getElementById("activity").value;

    try {
      const response = await fetch(
        `/activities/${encodeURIComponent(activity)}/signup?email=${encodeURIComponent(email)}`,
        {
          method: "POST",
        }
      );

      const result = await response.json();

      if (response.ok) {
        messageDiv.textContent = result.message;
        messageDiv.className = "success";
        signupForm.reset();

        // Rafraîchir la liste des activités pour mettre à jour la carte et participants
        await fetchActivities();
      } else {
        messageDiv.textContent = result.detail || "An error occurred";
        messageDiv.className = "error";
      }

      messageDiv.classList.remove("hidden");

      // Hide message after 5 seconds
      setTimeout(() => {
        messageDiv.classList.add("hidden");
      }, 5000);
    } catch (error) {
      messageDiv.textContent = "Failed to sign up. Please try again.";
      messageDiv.className = "error";
      messageDiv.classList.remove("hidden");
      console.error("Error signing up:", error);
    }
  });

  // Initialize app
  fetchActivities();
});
