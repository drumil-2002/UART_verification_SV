# UART Verification (SystemVerilog, UVM-Style)

## 📌 Overview
Verification of a **UART TX/RX design** using a **SystemVerilog UVM-style class-based environment**.  
The testbench supports both **write (TX)** and **read (RX)** operations, randomizes transactions, and uses a scoreboard to compare transmitted/received bytes.

---

## 📁 Structure
rtl/ → uart_design, uarttx, uartrx
tb/ → transaction, generator, driver, monitor, scoreboard, environment, uart_if, tb_top

---

## 🧪 How It Works
- **Generator:** Randomizes `oper` (write/read) + 8-bit data  
- **Driver:**  
  - For TX: sends `dintx`, pulses `newd`, waits for `donetx`  
  - For RX: drives `rx` bits into the receiver, waits for `donerx`
- **Monitor:**  
  - Samples transmitted bits from `tx`  
  - Samples received byte from `doutrx`
- **Scoreboard:**  
  - Compares driver-sent data vs monitor-observed data  
  - Prints PASS/FAIL for each byte  
- **Environment:** Connects all components and coordinates test execution

---

---

## ⭐ Features
- UVM-style modular architecture  
- Random TX/RX transactions  
- Self-checking scoreboard  
- Separate TX and RX sampling clocks  
- UART bit-level capture in monitor  
- Fully class-based environment

---

## 🚀 Future Improvements
- Add parity & stop-bit checks  
- Add constrained random baud-rate scenarios  
- Add full UVM integration  