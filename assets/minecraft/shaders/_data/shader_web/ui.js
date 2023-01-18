init()
function init() {
    var radioElements = document.getElementsByName("i-displacement");    
    for (var i=0; i<radioElements.length; i++) {
        if (radioElements[i].getAttribute('value') == '+') {
        radioElements[i].checked = true;
        }
    }

    
    { // 
        var displacement_toggle = document.getElementById("i-displacement-toggle");
        displacement_toggle.addEventListener('change', (event) => {
            var div_content_displacement = document.getElementById("content-displacement");
            if (event.currentTarget.checked) {
                div_content_displacement.hidden = false;
            } else {
                div_content_displacement.hidden = true;
            }
        });

        var offset_numbox = document.getElementById("i-displacement-offset-box");
        var offset_slider = document.getElementById("i-displacement-offset-slider");
        offset_slider.oninput = function() {
            offset_numbox.value = this.value;
        } 
        offset_numbox.oninput = function() {
            offset_slider.value = this.value;
        }      

        var asym_offset_numbox = document.getElementById("i-asym-displacement-offset-box");
        var asym_offset_slider = document.getElementById("i-asym-displacement-offset-slider");
        asym_offset_slider.oninput = function() {
            asym_offset_numbox.value = this.value;
        } 
        asym_offset_numbox.oninput = function() {
            asym_offset_slider.value = this.value;
        }       

        var asym_mode_box = document.getElementById("i-displacement-asym-mode")
        asym_mode_box.addEventListener('change', (event) => {
            var div_content_asym_displacement = document.getElementById("content-asym-direct-offset")
            if (event.currentTarget.value == "direct") {
                div_content_asym_displacement.hidden = false;
            } else {
                div_content_asym_displacement.hidden = true;
            }
        });
    }
}

output.innerHTML = slider.value; // Display the default slider value

// Update the current slider value (each time you drag the slider handle)
